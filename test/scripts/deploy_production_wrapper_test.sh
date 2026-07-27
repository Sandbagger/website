#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

cat > "$temp_dir/bundle" <<'BUNDLE'
#!/usr/bin/env bash
printf 'bundle:%s\n' "$*" >> "$EVENTS_FILE"
BUNDLE
chmod +x "$temp_dir/bundle"

cat > "$temp_dir/ssh" <<'SSH'
#!/usr/bin/env bash
printf 'ssh:%s\n' "$*" >> "$EVENTS_FILE"
cat > /dev/null
SSH
chmod +x "$temp_dir/ssh"

assert_rejected_option() {
  local expected_option=$1 case_name=$2
  shift 2

  : > "$temp_dir/events"
  if EVENTS_FILE="$temp_dir/events" \
    DEPLOY_ENV_FILE="$temp_dir/production.env" \
    PATH="$temp_dir:$PATH" \
    "$project_root/bin/deploy" logs "$@" \
      >"$temp_dir/rejected-$case_name.out" 2>&1; then
    echo "expected production option $expected_option to fail" >&2
    exit 1
  fi
  grep -Fx "error=unsupported_kamal_option option=$expected_option" \
    "$temp_dir/rejected-$case_name.out"
  test ! -s "$temp_dir/events"
}

cat > "$temp_dir/production.env" <<'ENV'
KAMAL_HOST=shared-kamal-01
APP_SHARED_ROOT=/srv/apps/website/shared
ENV

EVENTS_FILE="$temp_dir/events" \
DEPLOY_ENV_FILE="$temp_dir/production.env" \
PATH="$temp_dir:$PATH" \
"$project_root/bin/deploy" config

grep -Fx \
  'ssh:root@shared-kamal-01 bash -s -- /srv/apps/website/shared 0' \
  "$temp_dir/events"
grep -Fx 'bundle:exec kamal version' "$temp_dir/events"
grep -Fx 'bundle:exec kamal config' "$temp_dir/events"

assert_rejected_option -d short-d -d staging
assert_rejected_option -dstaging attached-d -dstaging
assert_rejected_option --destination long-d --destination staging
assert_rejected_option --destination=staging value-d --destination=staging
assert_rejected_option -c short-c -c config/other.yml
assert_rejected_option -cconfig/other.yml attached-c -cconfig/other.yml
assert_rejected_option --config-file long-c --config-file config/other.yml
assert_rejected_option \
  --config-file=config/other.yml value-c --config-file=config/other.yml
assert_rejected_option -H short-hooks -H
assert_rejected_option --skip-hooks long-hooks --skip-hooks
assert_rejected_option --skip-hooks=true value-hooks --skip-hooks=true

cat > "$temp_dir/adversarial-routing.env" <<'ENV'
KAMAL_HOST=shared-kamal-01
APP_SHARED_ROOT=/srv/apps/website/shared
destination=staging
default_env_file=/tmp/attacker.env
handoff_service=attacker
expected_shared_root=/srv/apps/website-staging/shared
ENV_FILE=/tmp/attacker.env
HERE=/tmp/attacker
ENV

: > "$temp_dir/events"
EVENTS_FILE="$temp_dir/events" \
DEPLOY_ENV_FILE="$temp_dir/adversarial-routing.env" \
PATH="$temp_dir:$PATH" \
"$project_root/bin/deploy" logs -r web

grep -Fx \
  'ssh:root@shared-kamal-01 bash -s -- /srv/apps/website/shared 0' \
  "$temp_dir/events"
grep -Fx 'bundle:exec kamal version' "$temp_dir/events"
grep -Fx 'bundle:exec kamal logs -r web' "$temp_dir/events"
if grep -Fq 'bundle:exec kamal -d' "$temp_dir/events"; then
  echo 'production routing was changed by sourced environment variables' >&2
  exit 1
fi

cat > "$temp_dir/staging-path.env" <<'ENV'
KAMAL_HOST=shared-kamal-01
APP_SHARED_ROOT=/srv/apps/website-staging/shared
ENV

: > "$temp_dir/events"
if EVENTS_FILE="$temp_dir/events" \
  DEPLOY_ENV_FILE="$temp_dir/staging-path.env" \
  PATH="$temp_dir:$PATH" \
  "$project_root/bin/deploy" config >"$temp_dir/wrong-path.out" 2>&1; then
  echo 'expected production with the staging shared root to fail' >&2
  exit 1
fi
grep -Fx \
  'error=unexpected_app_shared_root expected=/srv/apps/website/shared' \
  "$temp_dir/wrong-path.out"
test ! -s "$temp_dir/events"

if DEPLOY_ENV_FILE="$temp_dir/missing-production.env" PATH="$temp_dir:$PATH" \
  "$project_root/bin/deploy" config >"$temp_dir/missing-env.out" 2>&1; then
  echo 'expected a missing production environment file to fail' >&2
  exit 1
fi
grep -Fx \
  "hint=dotfiles-hetzner-tf handoff website --format env > $project_root/.env.deploy" \
  "$temp_dir/missing-env.out"

cat > "$temp_dir/missing-var.env" <<'ENV'
APP_SHARED_ROOT=/srv/apps/website/shared
ENV
if DEPLOY_ENV_FILE="$temp_dir/missing-var.env" PATH="$temp_dir:$PATH" \
  "$project_root/bin/deploy" config >"$temp_dir/missing-var.out" 2>&1; then
  echo 'expected missing production variables to fail' >&2
  exit 1
fi
grep -Fx \
  "hint=edit $temp_dir/missing-var.env in place; do not regenerate or overwrite it" \
  "$temp_dir/missing-var.out"
