#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

fail() {
  echo "test failure: $*" >&2
  exit 1
}

assert_contains() {
  local expected=$1 file=$2
  grep -Fq "$expected" "$file" || fail "expected $file to contain: $expected"
}

assert_not_contains() {
  local expected=$1 file=$2
  if [[ -f $file ]] && grep -Fq "$expected" "$file"; then
    fail "expected $file not to contain: $expected"
  fi
}

app_dir="$temp_dir/app"
mkdir -p "$app_dir/bin" "$temp_dir/storage"

cat > "$app_dir/bin/rails" <<'RAILS'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$RAILS_CALLS_FILE"

case "${1:-}" in
  db:prepare)
    ;;
  runner)
    [[ ${2:-} == *"PRAGMA journal_mode"* ]] || exit 17
    [[ ! -e $LITESTREAM_READY_MARKER ]] || exit 18
    printf '%s\n' "${JOURNAL_MODE:-wal}"
    ;;
  server)
    ;;
  litestream:replicate)
    ;;
esac
RAILS
chmod +x "$app_dir/bin/rails"

marker="$temp_dir/storage/.web-ready"
calls="$temp_dir/rails-calls"
cd "$app_dir"

# The web server initializes SQLite, verifies WAL mode with Rails, then publishes readiness.
RAILS_CALLS_FILE="$calls" \
LITESTREAM_READY_MARKER="$marker" \
JOURNAL_MODE=wal \
"$project_root/bin/docker-entrypoint" ./bin/rails server \
  >/dev/null

assert_contains 'db:prepare' "$calls"
assert_contains 'runner puts ActiveRecord::Base.connection.select_value('"'"'PRAGMA journal_mode'"'"')' "$calls"
assert_contains 'server' "$calls"
[[ -f $marker ]] || fail "web server did not create readiness marker"

# A non-WAL database aborts startup and never publishes readiness.
rm -f "$marker" "$calls"
if readiness_output=$(RAILS_CALLS_FILE="$calls" \
  LITESTREAM_READY_MARKER="$marker" \
  JOURNAL_MODE=delete \
  "$project_root/bin/docker-entrypoint" ./bin/rails server 2>&1); then
  fail "web server accepted a non-WAL journal mode"
fi
[[ $readiness_output == *'error=sqlite_not_wal journal_mode=delete'* ]] || fail "missing non-WAL error"
[[ ! -e $marker ]] || fail "non-WAL startup created readiness marker"
assert_not_contains 'server' "$calls"

# Non-web commands leave both database preparation and readiness untouched.
printf 'existing marker\n' > "$marker"
rm -f "$calls"
RAILS_CALLS_FILE="$calls" \
LITESTREAM_READY_MARKER="$marker" \
"$project_root/bin/docker-entrypoint" ./bin/rails console \
  >/dev/null
assert_not_contains 'db:prepare' "$calls"
[[ $(<"$marker") == 'existing marker' ]] || fail "non-web command changed readiness marker"

# Litestream cannot start until the web role publishes readiness.
rm -f "$marker" "$calls"
RAILS_CALLS_FILE="$calls" \
LITESTREAM_READY_MARKER="$marker" \
LITESTREAM_READY_TIMEOUT=5 \
"$project_root/bin/litestream-entrypoint" \
  >/dev/null &
litestream_pid=$!
sleep 1
assert_not_contains 'litestream:replicate' "$calls"
install -m 0640 /dev/null "$marker"
wait "$litestream_pid"
assert_contains 'litestream:replicate' "$calls"

# Invalid timeout values fail before Litestream can start.
rm -f "$marker" "$calls"
invalid_timeout_output="$temp_dir/invalid-timeout-output"
RAILS_CALLS_FILE="$calls" \
LITESTREAM_READY_MARKER="$marker" \
LITESTREAM_READY_TIMEOUT=08 \
"$project_root/bin/litestream-entrypoint" \
  > "$invalid_timeout_output" 2>&1 &
invalid_timeout_pid=$!
sleep 2
if kill -0 "$invalid_timeout_pid" 2>/dev/null; then
  kill "$invalid_timeout_pid"
  wait "$invalid_timeout_pid" || true
  fail "Litestream did not reject an invalid readiness timeout"
fi
if wait "$invalid_timeout_pid"; then
  fail "Litestream accepted an invalid readiness timeout"
fi
assert_contains 'error=invalid_litestream_readiness_timeout' "$invalid_timeout_output"
assert_not_contains 'litestream:replicate' "$calls"

# A missing marker times out predictably without starting Litestream.
rm -f "$marker" "$calls"
if timeout_output=$(RAILS_CALLS_FILE="$calls" \
  LITESTREAM_READY_MARKER="$marker" \
  LITESTREAM_READY_TIMEOUT=1 \
  "$project_root/bin/litestream-entrypoint" 2>&1); then
  fail "Litestream started without readiness"
fi
[[ $timeout_output == *'error=litestream_readiness_timeout'* ]] || fail "missing readiness timeout error"
assert_not_contains 'litestream:replicate' "$calls"

# Kamal's primary-role barrier starts web before Litestream; preserve the wrapper
# and shared readiness settings without serializing roles outside that barrier.
deploy_config="$project_root/config/deploy.yml"
assert_contains 'cmd: ./bin/litestream-entrypoint' "$deploy_config"
assert_contains 'LITESTREAM_READY_MARKER: /rails/storage/.web-ready' "$deploy_config"
assert_contains 'LITESTREAM_READY_TIMEOUT: "60"' "$deploy_config"
assert_not_contains 'parallel_roles:' "$deploy_config"
