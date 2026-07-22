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
#!/bin/bash
logged_arguments=$*
logged_arguments=${logged_arguments//$'\n'/\\n}
printf '%s\n' "$logged_arguments" >> "$BUNDLE_LOG"

if [[ "${BUNDLE_MODE:-success}" == "fail" ]]; then
  exit 1
fi

if [[ "${BUNDLE_MODE:-success}" == "hang" ]]; then
  printf '%s\n' "$*" > "$BUNDLE_HANG_ARGS_LOG"
  while :; do
    :
  done
fi

if [[ "${BUNDLE_MODE:-success}" == "parse" ]]; then
  remote_command="${!#}"
  /bin/sh -c "$remote_command"
fi
BUNDLE
chmod +x "$temp_dir/bundle"

cat > "$temp_dir/bash" <<'BASH'
#!/bin/bash
if [[ "${1:-}" == "-lc" ]]; then
  printf '%s' "${2:-}" > "$BASH_REMOTE_SCRIPT_LOG"
  exit 0
fi

exec /bin/bash "$@"
BASH
chmod +x "$temp_dir/bash"

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
grep -F 'litestream restore -config config/litestream.yml -o /tmp/litestream-verify.sqlite3 /rails/storage/db/production.sqlite3' "$success_log"
grep -F 'SQLite3::Database' "$success_log"
grep -F 'PRAGMA integrity_check' "$success_log"

parsed_remote_script="$temp_dir/parsed-remote-script"
PATH="$temp_dir:$PATH" \
BUNDLE_LOG="$temp_dir/parse.log" \
BUNDLE_MODE=parse \
BASH_REMOTE_SCRIPT_LOG="$parsed_remote_script" \
KAMAL_DESTINATION=staging \
LITESTREAM_REPLICA_VERIFY_TIMEOUT=1 \
"$verifier"

expected_remote_script=$(cat <<'REMOTE'
set -euo pipefail

restore_path=/tmp/litestream-verify.sqlite3
rm -f -- "$restore_path"
trap 'rm -f -- "$restore_path"' EXIT

litestream restore -config config/litestream.yml -o /tmp/litestream-verify.sqlite3 /rails/storage/db/production.sqlite3
ruby -r sqlite3 -e 'database = SQLite3::Database.new(ARGV.fetch(0)); integrity_check = database.get_first_value("PRAGMA integrity_check"); abort "integrity_check=#{integrity_check.inspect}" unless integrity_check == "ok"' "$restore_path"
rm -f -- "$restore_path"
REMOTE
)
[[ -f "$parsed_remote_script" ]]
[[ $(< "$parsed_remote_script") == "$expected_remote_script" ]]

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
hung_args="$temp_dir/hung-args.log"
hung_path="$temp_dir:$PATH"
set +e
PATH="$hung_path" \
BUNDLE_LOG="$temp_dir/hung.log" \
BUNDLE_HANG_ARGS_LOG="$hung_args" \
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

if [[ ! -f "$hung_args" ]]; then
  echo "hanging bundle stub did not record its arguments" >&2
  exit 1
fi
grep -F 'exec kamal -d staging app exec -r web --reuse ' "$hung_args"
if [[ $hung_status -eq 124 ]]; then
  echo "verifier did not enforce its per-attempt timeout" >&2
  exit 1
fi
[[ $hung_status -eq 1 ]]
[[ $(grep -Fxc 'error=litestream_replica_verification_timeout' "$hung_stderr") -eq 1 ]]
