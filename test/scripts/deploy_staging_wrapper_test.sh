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
    DEPLOY_ENV_FILE="$temp_dir/staging.env" \
    PATH="$temp_dir:$PATH" \
    "$project_root/bin/deploy" staging logs "$@" \
      >"$temp_dir/rejected-$case_name.out" 2>&1; then
    echo "expected staging option $expected_option to fail" >&2
    exit 1
  fi
  grep -Fx "error=unsupported_kamal_option option=$expected_option" \
    "$temp_dir/rejected-$case_name.out"
  test ! -s "$temp_dir/events"
}

cat > "$temp_dir/staging.env" <<'ENV'
KAMAL_HOST=shared-kamal-01
APP_SHARED_ROOT=/srv/apps/website-staging/shared
ENV

EVENTS_FILE="$temp_dir/events" \
DEPLOY_ENV_FILE="$temp_dir/staging.env" \
PATH="$temp_dir:$PATH" \
"$project_root/bin/deploy" staging config

grep -Fx 'ssh:root@shared-kamal-01 bash -s -- /srv/apps/website-staging/shared 0' "$temp_dir/events"
grep -Fx 'bundle:exec kamal version' "$temp_dir/events"
grep -Fx 'bundle:exec kamal -d staging config' "$temp_dir/events"

preflight_line=$(grep -n '^ssh:' "$temp_dir/events" | cut -d: -f1)
version_line=$(grep -n '^bundle:exec kamal version$' "$temp_dir/events" | cut -d: -f1)
destination_line=$(grep -n '^bundle:exec kamal -d staging config$' "$temp_dir/events" | cut -d: -f1)
(( preflight_line < version_line ))
(( preflight_line < destination_line ))

assert_rejected_option -d short-d -d production
assert_rejected_option -dproduction attached-d -dproduction
assert_rejected_option --destination long-d --destination production
assert_rejected_option --destination=production value-d --destination=production
assert_rejected_option -vd bundled-d -vd production
assert_rejected_option -c short-c -c config/other.yml
assert_rejected_option -cconfig/other.yml attached-c -cconfig/other.yml
assert_rejected_option --config-file long-c --config-file config/other.yml
assert_rejected_option \
  --config-file=config/other.yml value-c --config-file=config/other.yml
assert_rejected_option -vc bundled-c -vc config/other.yml
assert_rejected_option -qvcconfig/other.yml bundled-qvc -qvcconfig/other.yml
assert_rejected_option -H short-hooks -H
assert_rejected_option -H=true value-short-hooks -H=true
assert_rejected_option -Hfalse attached-short-hooks -Hfalse
assert_rejected_option -vH bundled-hooks -vH
assert_rejected_option -Hv reverse-bundled-hooks -Hv
assert_rejected_option --skip-hooks long-hooks --skip-hooks
assert_rejected_option --skip-hooks=true value-hooks --skip-hooks=true
assert_rejected_option -xv ambiguous-bundle -xv

cat > "$temp_dir/adversarial-routing.env" <<'ENV'
KAMAL_HOST=shared-kamal-01
APP_SHARED_ROOT=/srv/apps/website-staging/shared
destination=
default_env_file=/tmp/attacker.env
handoff_service=attacker
expected_shared_root=/srv/apps/website/shared
ENV_FILE=/tmp/attacker.env
HERE=/tmp/attacker
ENV

: > "$temp_dir/events"
EVENTS_FILE="$temp_dir/events" \
DEPLOY_ENV_FILE="$temp_dir/adversarial-routing.env" \
PATH="$temp_dir:$PATH" \
"$project_root/bin/deploy" staging logs -r web

grep -Fx \
  'ssh:root@shared-kamal-01 bash -s -- /srv/apps/website-staging/shared 0' \
  "$temp_dir/events"
grep -Fx 'bundle:exec kamal version' "$temp_dir/events"
grep -Fx 'bundle:exec kamal -d staging logs -r web' "$temp_dir/events"

cat > "$temp_dir/production-path.env" <<'ENV'
KAMAL_HOST=shared-kamal-01
APP_SHARED_ROOT=/srv/apps/website/shared
ENV

: > "$temp_dir/events"
if EVENTS_FILE="$temp_dir/events" \
  DEPLOY_ENV_FILE="$temp_dir/production-path.env" \
  PATH="$temp_dir:$PATH" \
  "$project_root/bin/deploy" staging config \
    >"$temp_dir/wrong-path.out" 2>&1; then
  echo 'expected staging with the production shared root to fail' >&2
  exit 1
fi
grep -Fx \
  'error=unexpected_app_shared_root expected=/srv/apps/website-staging/shared' \
  "$temp_dir/wrong-path.out"
test ! -s "$temp_dir/events"

missing_env="$temp_dir/missing-staging.env"
if DEPLOY_ENV_FILE="$missing_env" PATH="$temp_dir:$PATH" \
  "$project_root/bin/deploy" staging config \
    >"$temp_dir/missing-env.out" 2>&1; then
  echo 'expected a missing staging environment file to fail' >&2
  exit 1
fi
grep -Fx \
  "hint=dotfiles-hetzner-tf handoff website-staging --format env > $project_root/.env.deploy.staging" \
  "$temp_dir/missing-env.out"

cat > "$temp_dir/missing-var.env" <<'ENV'
KAMAL_HOST=shared-kamal-01
ENV
if DEPLOY_ENV_FILE="$temp_dir/missing-var.env" PATH="$temp_dir:$PATH" \
  "$project_root/bin/deploy" staging config \
    >"$temp_dir/missing-var.out" 2>&1; then
  echo 'expected missing staging variables to fail' >&2
  exit 1
fi
grep -Fx \
  "hint=edit $temp_dir/missing-var.env in place; do not regenerate or overwrite it" \
  "$temp_dir/missing-var.out"
