#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)
verifier="$project_root/bin/verify-litestream-replica"
hook="$project_root/.kamal/hooks/post-deploy"
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

if [[ ! -x "$verifier" ]]; then
  echo "expected executable verifier at $verifier" >&2
  exit 1
fi

cat > "$temp_dir/bundle" <<'BUNDLE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$BUNDLE_LOG"

if [[ "${BUNDLE_MODE:-success}" == "fail" ]]; then
  exit 1
fi

if [[ "${BUNDLE_MODE:-success}" == "hang" ]]; then
  while :; do
    :
  done
fi
BUNDLE
chmod +x "$temp_dir/bundle"

cat > "$temp_dir/sleep" <<'SLEEP'
#!/usr/bin/env bash
:
SLEEP
chmod +x "$temp_dir/sleep"

run_verifier() {
  PATH="$temp_dir:$PATH" \
  BUNDLE_LOG="$1" \
  KAMAL_DESTINATION=staging \
  LITESTREAM_REPLICA_VERIFY_TIMEOUT=1 \
  "$verifier"
}

success_log="$temp_dir/success.log"
run_verifier "$success_log"

[[ $(wc -l < "$success_log" | tr -d ' ') -eq 1 ]]
grep -F 'exec kamal -d staging app exec -r web --reuse ' "$success_log"
if grep -Fq 'exec kamal -d production' "$success_log" || grep -Fq ' -r litestream' "$success_log"; then
  echo "verifier targeted the wrong Kamal destination or role" >&2
  exit 1
fi

grep -F 'restore_path=/tmp/litestream-verify.sqlite3' "$success_log"
grep -F "rm -f -- \"\$restore_path\"" "$success_log"
grep -F "trap \\'rm -f -- \"\$restore_path\"\\' EXIT" "$success_log"
grep -F 'litestream restore -config config/litestream.yml -o /tmp/litestream-verify.sqlite3 /rails/storage/db/production.sqlite3' "$success_log"
grep -F 'SQLite3::Database' "$success_log"
grep -F 'PRAGMA integrity_check' "$success_log"

failed_log="$temp_dir/failed.log"
failed_stderr="$temp_dir/failed.stderr"
set +e
PATH="$temp_dir:$PATH" \
BUNDLE_LOG="$failed_log" \
BUNDLE_MODE=fail \
KAMAL_DESTINATION=staging \
LITESTREAM_REPLICA_VERIFY_TIMEOUT=1 \
"$verifier" 2> "$failed_stderr"
failed_status=$?
set -e

[[ $failed_status -ne 0 ]]
[[ $(wc -l < "$failed_log" | tr -d ' ') -eq 2 ]]
[[ $(grep -Fxc 'error=litestream_replica_verification_timeout' "$failed_stderr") -eq 1 ]]
while IFS= read -r attempt; do
  [[ "$attempt" == *"rm -f -- \"\$restore_path\""* ]]
  [[ "$attempt" == *'litestream restore -config config/litestream.yml -o /tmp/litestream-verify.sqlite3 /rails/storage/db/production.sqlite3'* ]]
  cleanup_offset=${attempt%%litestream restore*}
  [[ "$cleanup_offset" == *"rm -f -- \"\$restore_path\""* ]]
done < "$failed_log"

[[ -x "$hook" ]]
hook_log="$temp_dir/hook.log"
PATH="$temp_dir:$PATH" \
BUNDLE_LOG="$hook_log" \
KAMAL_DESTINATION=staging \
LITESTREAM_REPLICA_VERIFY_TIMEOUT=1 \
"$hook"
grep -F 'exec kamal -d staging app exec -r web --reuse ' "$hook_log"

hook_failed_stderr="$temp_dir/hook-failed.stderr"
set +e
PATH="$temp_dir:$PATH" \
BUNDLE_LOG="$temp_dir/hook-failed.log" \
BUNDLE_MODE=fail \
KAMAL_DESTINATION=staging \
LITESTREAM_REPLICA_VERIFY_TIMEOUT=1 \
"$hook" 2> "$hook_failed_stderr"
hook_failed_status=$?
set -e

[[ $hook_failed_status -ne 0 ]]
[[ $(grep -Fxc 'error=litestream_replica_verification_timeout' "$hook_failed_stderr") -eq 1 ]]

hung_stderr="$temp_dir/hung.stderr"
hung_path="$temp_dir:$PATH"
set +e
PATH="$hung_path" \
BUNDLE_LOG="$temp_dir/hung.log" \
BUNDLE_MODE=hang \
KAMAL_DESTINATION=staging \
LITESTREAM_REPLICA_VERIFY_TIMEOUT=1 \
KAMAL_EXEC_PATH="$hung_path" \
ruby -r timeout -e '
  environment = ENV.to_h
  environment["PATH"] = environment.fetch("KAMAL_EXEC_PATH")
  child = Process.spawn(environment, *ARGV, pgroup: true)
  begin
    Timeout.timeout(2) { Process.wait(child) }
  rescue Timeout::Error
    Process.kill("KILL", -child) rescue nil
    Process.wait(child) rescue nil
    exit 124
  end
  exit($?.success? ? 0 : 1)
' "$verifier" 2> "$hung_stderr"
hung_status=$?
set -e

if [[ $hung_status -eq 124 ]]; then
  echo "verifier did not enforce its per-attempt timeout" >&2
  exit 1
fi
[[ $hung_status -eq 1 ]]
[[ $(grep -Fxc 'error=litestream_replica_verification_timeout' "$hung_stderr") -eq 1 ]]
