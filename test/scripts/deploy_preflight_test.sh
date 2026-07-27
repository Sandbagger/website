#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

cat > "$temp_dir/ssh" <<'SSH'
#!/usr/bin/env bash
if [[ "${SSH_EXECUTE_REMOTE:-}" == '1' ]]; then
  shift
  if [[ "$1" != 'bash' || "$2" != '-s' || "$3" != '--' ]]; then
    echo 'unexpected ssh command' >&2
    exit 64
  fi
  shift 3
  exec env BASH_ENV="$REMOTE_BASH_ENV" bash -s -- "$@"
fi

printf '%s\n' "$@" > "$SSH_ARGS_FILE"
cat > "$SSH_STDIN_FILE"
SSH
chmod +x "$temp_dir/ssh"

mkdir "$temp_dir/remote-bin"

cat > "$temp_dir/remote-bin/findmnt" <<'FINDMNT'
#!/usr/bin/env bash
if [[ "${PREFLIGHT_STATE:-}" == 'same_mount' ]]; then
  echo '/dev/vda1'
elif [[ "${!#}" == '/srv' ]]; then
  echo '/dev/vdb1'
else
  echo '/dev/vda1'
fi
FINDMNT

cat > "$temp_dir/remote-bin/stat" <<'STAT'
#!/usr/bin/env bash
target=${!#}
case "${PREFLIGHT_STATE:-}:$target" in
  apps_owner_bad:/srv/apps)
    echo '1000:1000'
    ;;
  app_owner_bad:/srv/apps/website/shared|db_owner_bad:/srv/apps/website/shared/db)
    echo '0:0'
    ;;
  *:/srv/apps)
    echo '0:0'
    ;;
  *)
    echo '1000:1000'
    ;;
esac
STAT

cat > "$temp_dir/remote-bin/ss" <<'SS'
#!/usr/bin/env bash
if [[ "${PREFLIGHT_STATE:-}" == 'foreign_ingress' ]]; then
  echo 'LISTEN 0 511 0.0.0.0:80 0.0.0.0:* users:(("nginx",pid=1,fd=6))'
fi
SS

cat > "$temp_dir/remote-bin/docker" <<'DOCKER'
#!/usr/bin/env bash
case "${PREFLIGHT_STATE:-}" in
  foreign_container)
    printf '%s\n' \
      $'kamal-proxy\t0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp' \
      $'foreign-service\t0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp'
    ;;
  wrong_proxy)
    printf '%s\n' $'kamal-proxy-old\t0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp'
    ;;
  proxy_missing_port)
    printf '%s\n' $'kamal-proxy\t0.0.0.0:80->80/tcp'
    ;;
esac
DOCKER

chmod +x "$temp_dir/remote-bin/findmnt" "$temp_dir/remote-bin/stat" \
  "$temp_dir/remote-bin/ss" "$temp_dir/remote-bin/docker"

cat > "$temp_dir/remote-bash-env" <<'BASH_ENV'
test() {
  case "$1:${2:-}" in
    -f:/srv/bootstrap/.layout-ready)
      [[ "${PREFLIGHT_STATE:-}" != 'missing_layout' ]]
      ;;
    -e:/srv/apps/website/shared|-d:/srv/apps/website/shared|-d:/srv/apps/website/shared/db)
      [[ "${PREFLIGHT_STATE:-}" == 'app_owner_bad' || "${PREFLIGHT_STATE:-}" == 'db_owner_bad' ]]
      ;;
    -L:/srv/apps/website/shared)
      [[ "${PREFLIGHT_STATE:-}" == 'symlink' ]]
      ;;
    *)
      builtin test "$@"
      ;;
  esac
}
BASH_ENV

run_preflight() {
  SSH_ARGS_FILE="$temp_dir/ssh-args" \
  SSH_STDIN_FILE="$temp_dir/ssh-stdin" \
  PATH="$temp_dir:$PATH" \
  KAMAL_HOST=shared-kamal-01 \
  APP_SHARED_ROOT=/srv/apps/website/shared \
  KAMAL_REGISTRY_PASSWORD=registry-secret-should-not-appear \
  RAILS_MASTER_KEY=rails-secret-should-not-appear \
  "$project_root/bin/deploy-preflight"
}

assert_normalized_root_disk_flag() {
  local source_value=$1
  local expected_value=$2
  local case_name=$3

  ALLOW_ROOT_DISK_STORAGE="$source_value" \
    run_preflight >"$temp_dir/capture-$case_name.out" 2>&1

  test "$(sed -n '5p' "$temp_dir/ssh-args")" = '/srv/apps/website/shared'
  test "$(sed -n '6p' "$temp_dir/ssh-args")" = "$expected_value"
  test "$(sed -n '7p' "$temp_dir/ssh-args")" = ''
}

run_preflight >"$temp_dir/capture.out" 2>&1

run_remote_failure_case() {
  local state=$1
  local expected_error=$2
  local output_file="$temp_dir/$state.out"

  if SSH_EXECUTE_REMOTE=1 \
    REMOTE_BASH_ENV="$temp_dir/remote-bash-env" \
    PREFLIGHT_STATE="$state" \
    PATH="$temp_dir:$temp_dir/remote-bin:$PATH" \
    KAMAL_HOST=shared-kamal-01 \
    APP_SHARED_ROOT=/srv/apps/website/shared \
    "$project_root/bin/deploy-preflight" >"$output_file" 2>&1; then
    echo "expected $state to fail" >&2
    exit 1
  fi

  if ! grep -Fx "error=$expected_error" "$output_file"; then
    cat "$output_file" >&2
    exit 1
  fi
}

run_remote_failure_case missing_layout bootstrap_layout_not_ready
run_remote_failure_case same_mount srv_not_separate_filesystem
ALLOW_ROOT_DISK_STORAGE=true run_remote_failure_case same_mount srv_not_separate_filesystem
ALLOW_ROOT_DISK_STORAGE='' run_remote_failure_case same_mount srv_not_separate_filesystem
run_remote_failure_case apps_owner_bad apps_owner_invalid
run_remote_failure_case app_owner_bad app_shared_root_owner_invalid
run_remote_failure_case db_owner_bad app_shared_db_owner_invalid
run_remote_failure_case symlink app_shared_root_symlink
run_remote_failure_case foreign_ingress foreign_ingress_listener
run_remote_failure_case foreign_container foreign_ingress_container
run_remote_failure_case wrong_proxy foreign_ingress_container
run_remote_failure_case proxy_missing_port kamal_proxy_ports_invalid

grep -Fx 'root@shared-kamal-01' "$temp_dir/ssh-args"
grep -Fx -- '/srv/apps/website/shared' "$temp_dir/ssh-args"
test "$(sed -n '5p' "$temp_dir/ssh-args")" = '/srv/apps/website/shared'
test "$(sed -n '6p' "$temp_dir/ssh-args")" = '0'
test "$(sed -n '7p' "$temp_dir/ssh-args")" = ''
grep -F 'test -f /srv/bootstrap/.layout-ready || fail bootstrap_layout_not_ready' "$temp_dir/ssh-stdin"
grep -F 'findmnt -n -o SOURCE --target /srv' "$temp_dir/ssh-stdin"
grep -F 'findmnt -n -o SOURCE --target /' "$temp_dir/ssh-stdin"
grep -F 'fail srv_not_separate_filesystem' "$temp_dir/ssh-stdin"
grep -F 'stat -c '\''%u:%g'\'' -- /srv/apps' "$temp_dir/ssh-stdin"
grep -F 'fail apps_owner_invalid' "$temp_dir/ssh-stdin"
grep -F "if test -e \"\$app_shared_root\"; then" "$temp_dir/ssh-stdin"
grep -F "stat -c '%u:%g' -- \"\$app_shared_root\"" "$temp_dir/ssh-stdin"
grep -F "stat -c '%u:%g' -- \"\$app_shared_root/db\"" "$temp_dir/ssh-stdin"
grep -F 'fail app_shared_db_missing' "$temp_dir/ssh-stdin"
grep -F 'ss -H -ltnp' "$temp_dir/ssh-stdin"
grep -F "docker ps --format '{{.Names}}\\t{{.Ports}}'" "$temp_dir/ssh-stdin"
grep -F 'kamal-proxy' "$temp_dir/ssh-stdin"
grep -F 'fail foreign_ingress_listener' "$temp_dir/ssh-stdin"
grep -F 'fail foreign_ingress_container' "$temp_dir/ssh-stdin"
grep -F 'fail kamal_proxy_ports_invalid' "$temp_dir/ssh-stdin"
grep -F "[[ -n \"\$ingress_listeners\" && -z \"\$ingress_containers\" ]] && fail foreign_ingress_listener" "$temp_dir/ssh-stdin"

if grep -Fq 'registry-secret-should-not-appear' \
  "$temp_dir/ssh-args" "$temp_dir/ssh-stdin" "$temp_dir/capture.out"; then
  echo 'preflight forwarded the registry secret' >&2
  exit 1
fi

if grep -Fq 'rails-secret-should-not-appear' \
  "$temp_dir/ssh-args" "$temp_dir/ssh-stdin" "$temp_dir/capture.out"; then
  echo 'preflight forwarded the Rails secret' >&2
  exit 1
fi

assert_normalized_root_disk_flag true 0 invalid
assert_normalized_root_disk_flag '' 0 blank

ALLOW_ROOT_DISK_STORAGE=1 run_preflight >"$temp_dir/capture-allowed.out" 2>&1
test "$(sed -n '5p' "$temp_dir/ssh-args")" = '/srv/apps/website/shared'
test "$(sed -n '6p' "$temp_dir/ssh-args")" = '1'
test "$(sed -n '7p' "$temp_dir/ssh-args")" = ''

if grep -Fq 'registry-secret-should-not-appear' \
  "$temp_dir/ssh-args" "$temp_dir/ssh-stdin" "$temp_dir/capture-allowed.out"; then
  echo 'preflight forwarded the registry secret' >&2
  exit 1
fi

if grep -Fq 'rails-secret-should-not-appear' \
  "$temp_dir/ssh-args" "$temp_dir/ssh-stdin" "$temp_dir/capture-allowed.out"; then
  echo 'preflight forwarded the Rails secret' >&2
  exit 1
fi

if ! SSH_EXECUTE_REMOTE=1 \
  REMOTE_BASH_ENV="$temp_dir/remote-bash-env" \
  PREFLIGHT_STATE=same_mount \
  PATH="$temp_dir:$temp_dir/remote-bin:$PATH" \
  KAMAL_HOST=shared-kamal-01 \
  APP_SHARED_ROOT=/srv/apps/website/shared \
  ALLOW_ROOT_DISK_STORAGE=1 \
  KAMAL_REGISTRY_PASSWORD=registry-secret-should-not-appear \
  RAILS_MASTER_KEY=rails-secret-should-not-appear \
  "$project_root/bin/deploy-preflight" \
  >"$temp_dir/root-disk.out" 2>"$temp_dir/root-disk.err"; then
  echo 'expected root-disk opt-in to pass' >&2
  exit 1
fi
test ! -s "$temp_dir/root-disk.out"
test "$(cat "$temp_dir/root-disk.err")" = \
  'warning=root_disk_storage_enabled data_will_not_survive_server_loss'

if grep -Fq 'registry-secret-should-not-appear' \
  "$temp_dir/root-disk.out" "$temp_dir/root-disk.err"; then
  echo 'preflight exposed the registry secret' >&2
  exit 1
fi

if grep -Fq 'rails-secret-should-not-appear' \
  "$temp_dir/root-disk.out" "$temp_dir/root-disk.err"; then
  echo 'preflight exposed the Rails secret' >&2
  exit 1
fi

if ! env -u ALLOW_ROOT_DISK_STORAGE \
  SSH_EXECUTE_REMOTE=1 \
  REMOTE_BASH_ENV="$temp_dir/remote-bash-env" \
  PATH="$temp_dir:$temp_dir/remote-bin:$PATH" \
  KAMAL_HOST=shared-kamal-01 \
  APP_SHARED_ROOT=/srv/apps/website/shared \
  "$project_root/bin/deploy-preflight" \
  >"$temp_dir/separate-disk.out" 2>"$temp_dir/separate-disk.err"; then
  echo 'expected separate filesystem without opt-in to pass' >&2
  exit 1
fi
test ! -s "$temp_dir/separate-disk.out"
test ! -s "$temp_dir/separate-disk.err"

rm -f "$temp_dir/ssh-args"

if env -u KAMAL_HOST APP_SHARED_ROOT=/srv/apps/website/shared PATH="$temp_dir:$PATH" \
  "$project_root/bin/deploy-preflight" >"$temp_dir/missing.out" 2>&1; then
  echo 'expected missing KAMAL_HOST to fail' >&2
  exit 1
fi
grep -Fx 'error=missing_kamal_host' "$temp_dir/missing.out"
test ! -e "$temp_dir/ssh-args"

if env -u APP_SHARED_ROOT KAMAL_HOST=shared-kamal-01 PATH="$temp_dir:$PATH" \
  "$project_root/bin/deploy-preflight" >"$temp_dir/missing-root.out" 2>&1; then
  echo 'expected missing APP_SHARED_ROOT to fail' >&2
  exit 1
fi
grep -Fx 'error=missing_app_shared_root' "$temp_dir/missing-root.out"
test ! -e "$temp_dir/ssh-args"

if KAMAL_HOST=shared-kamal-01 APP_SHARED_ROOT=/tmp/shared PATH="$temp_dir:$PATH" \
  "$project_root/bin/deploy-preflight" >"$temp_dir/path.out" 2>&1; then
  echo 'expected invalid APP_SHARED_ROOT to fail' >&2
  exit 1
fi
grep -Fx 'error=invalid_app_shared_root' "$temp_dir/path.out"
test ! -e "$temp_dir/ssh-args"

if KAMAL_HOST=shared-kamal-01 APP_SHARED_ROOT=/srv/apps/website/nested/shared PATH="$temp_dir:$PATH" \
  "$project_root/bin/deploy-preflight" >"$temp_dir/nested-path.out" 2>&1; then
  echo 'expected nested APP_SHARED_ROOT to fail' >&2
  exit 1
fi
grep -Fx 'error=invalid_app_shared_root' "$temp_dir/nested-path.out"
test ! -e "$temp_dir/ssh-args"

mkdir "$temp_dir/failure-bin"
cat > "$temp_dir/failure-bin/ssh" <<'SSH'
#!/usr/bin/env bash
echo 'ssh transport detail: should-not-appear' >&2
exit 17
SSH
chmod +x "$temp_dir/failure-bin/ssh"

if KAMAL_HOST=shared-kamal-01 APP_SHARED_ROOT=/srv/apps/website/shared \
  PATH="$temp_dir/failure-bin:$PATH" \
  "$project_root/bin/deploy-preflight" >"$temp_dir/ssh-failure.out" 2>&1; then
  echo 'expected SSH transport failure to fail' >&2
  exit 1
fi
grep -Fx 'error=preflight_ssh_failed' "$temp_dir/ssh-failure.out"
if grep -F 'should-not-appear' "$temp_dir/ssh-failure.out"; then
  echo 'preflight exposed transport output' >&2
  exit 1
fi
