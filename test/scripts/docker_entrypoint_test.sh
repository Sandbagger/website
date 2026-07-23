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
mkdir -p "$app_dir/bin"

cat > "$app_dir/bin/rails" <<'RAILS'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$RAILS_CALLS_FILE"

case "${1:-}" in
  db:prepare)
    ;;
  runner)
    [[ ${2:-} == *"PRAGMA journal_mode"* ]] || exit 17
    printf '%s\n' "${JOURNAL_MODE:-wal}"
    ;;
  server | console)
    ;;
esac
RAILS
chmod +x "$app_dir/bin/rails"

calls="$temp_dir/rails-calls"
cd "$app_dir"

RAILS_CALLS_FILE="$calls" JOURNAL_MODE=wal \
  "$project_root/bin/docker-entrypoint" ./bin/rails server >/dev/null

assert_contains 'db:prepare' "$calls"
assert_contains "runner puts ActiveRecord::Base.connection.select_value('PRAGMA journal_mode')" "$calls"
assert_contains 'server' "$calls"

rm -f "$calls"
if output=$(RAILS_CALLS_FILE="$calls" JOURNAL_MODE=delete \
  "$project_root/bin/docker-entrypoint" ./bin/rails server 2>&1); then
  fail "web server accepted a non-WAL journal mode"
fi
[[ $output == *'error=sqlite_not_wal journal_mode=delete'* ]] || fail "missing non-WAL error"
assert_not_contains 'server' "$calls"

rm -f "$calls"
RAILS_CALLS_FILE="$calls" \
  "$project_root/bin/docker-entrypoint" ./bin/rails console >/dev/null
assert_not_contains 'db:prepare' "$calls"
