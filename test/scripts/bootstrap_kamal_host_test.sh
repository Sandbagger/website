#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
real_python=$(command -v python3)

fail() {
  echo "test failure: $*" >&2
  exit 1
}

assert_contains() {
  local expected=$1 file=$2
  grep -Fqx "$expected" "$file" || fail "expected $file to contain: $expected"
}

assert_not_contains() {
  local unexpected=$1 file=$2
  if [[ -f $file ]] && grep -Fq "$unexpected" "$file"; then
    fail "expected $file not to contain: $unexpected"
  fi
}

assert_failed_with() {
  local name=$1 expected_error=$2
  shift 2

  if run_remote "$name" "$@"; then
    fail "expected $name to fail"
  fi

  if [[ -n $expected_error ]]; then
    assert_contains "error=$expected_error" "$temp_dir/$name.output"
  fi
}

mkdir "$temp_dir/remote-bin"

cat > "$temp_dir/ssh" <<'SSH'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$@" > "$SSH_ARGS_FILE"
cat > "$SSH_STDIN_FILE"

if [[ ${SSH_EXECUTE_REMOTE:-0} == 1 ]]; then
  [[ $1 == root@* && $2 == bash && $3 == -s && $4 == -- ]] || exit 64
  shift
  remote_command=$*
  printf '%s\n' "$remote_command" > "$SSH_REMOTE_COMMAND_FILE"
  exec env BASH_ENV="$REMOTE_BASH_ENV" bash -c "$remote_command" \
    < "$SSH_STDIN_FILE"
fi
SSH

cat > "$temp_dir/remote-bash-env" <<'BASH_ENV'
managed_kind() {
  local path=$1

  if [[ ${INVALID_PATH:-} == "$path" ]]; then
    printf '%s\n' "${INVALID_KIND:-file}"
    return
  fi

  if [[ $path == /srv/bootstrap/.layout-ready ]]; then
    if [[ ${MARKER_KIND:-} == symlink || ${MARKER_KIND:-} == file ||
      ${MARKER_KIND:-} == directory ]]; then
      printf '%s\n' "$MARKER_KIND"
    elif [[ -s $MOCK_DIR/marker ]]; then
      printf '%s\n' file
    else
      printf '%s\n' absent
    fi
    return
  fi

  if [[ -s $MOCK_DIR/temp-marker ]] && [[ $(<"$MOCK_DIR/temp-marker") == "$path" ]]; then
    printf '%s\n' file
    return
  fi

  if grep -Fq "$path|" "$MOCK_DIR/metadata"; then
    printf '%s\n' directory
  else
    printf '%s\n' absent
  fi
}

test() {
  local operator=${1:-} path=${2:-} kind
  case "$operator" in
    -e)
      kind=$(managed_kind "$path")
      [[ $kind != absent ]]
      ;;
    -L)
      kind=$(managed_kind "$path")
      [[ $kind == symlink ]]
      ;;
    -d)
      kind=$(managed_kind "$path")
      [[ $kind == directory ]]
      ;;
    -f)
      kind=$(managed_kind "$path")
      [[ $kind == file ]]
      ;;
    *)
      builtin test "$@"
      ;;
  esac
}

source() {
  if [[ ${1:-} == /etc/os-release ]]; then
    [[ ${REMOTE_OS:-ubuntu-22.04} != missing ]] || return 1
    if [[ ${REMOTE_OS:-ubuntu-22.04} == ubuntu-22.04 ]]; then
      ID=ubuntu
      VERSION_ID=22.04
    else
      ID=debian
      VERSION_ID=12
    fi
  else
    builtin source "$@"
  fi
}

command() {
  if [[ ${1:-} == -v ]]; then
    case "${2:-}" in
      apt-get|systemctl|python3)
        [[ ${MISSING_COMMAND:-} != "$2" ]]
        ;;
      docker)
        [[ ${DOCKER_PRESENT:-0} == 1 || -e $MOCK_DIR/docker-installed ]]
        ;;
      *)
        builtin command "$@"
        ;;
    esac
  else
    builtin command "$@"
  fi
}
BASH_ENV

cat > "$temp_dir/remote-bin/findmnt" <<'FINDMNT'
#!/usr/bin/env bash
set -euo pipefail
target=${!#}
[[ ${FINDMNT_FAILURE:-} != "$target" ]] || exit 30
if [[ ${SAME_FILESYSTEM:-0} == 1 || $target == / ]]; then
  echo /dev/vda1
else
  echo /dev/vdb1
fi
FINDMNT

cat > "$temp_dir/remote-bin/apt-get" <<'APT'
#!/usr/bin/env bash
set -euo pipefail
printf 'apt-get:%s:%s\n' "${DEBIAN_FRONTEND:-}" "$*" >> "$EVENT_LOG"
[[ ${FAILURE:-} != package_update || ${1:-} != update ]] || exit 31
[[ ${FAILURE:-} != package_install || ${1:-} != install ]] || exit 31
if [[ ${1:-} == install ]]; then
  : > "$MOCK_DIR/docker-installed"
fi
APT

cat > "$temp_dir/remote-bin/systemctl" <<'SYSTEMCTL'
#!/usr/bin/env bash
set -euo pipefail
printf 'systemctl:%s\n' "$*" >> "$EVENT_LOG"
[[ ${FAILURE:-} != systemctl ]] || exit 32
SYSTEMCTL

cat > "$temp_dir/remote-bin/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
printf 'docker:%s\n' "$*" >> "$EVENT_LOG"
[[ ${FAILURE:-} != docker ]] || exit 33
[[ ${1:-} == info ]] || exit 64
DOCKER

cat > "$temp_dir/remote-bin/python3" <<'PYTHON'
#!/usr/bin/env bash
set -euo pipefail

printf 'python3:%s\n' "$*" >> "$EVENT_LOG"
/bin/cat > "$MOCK_DIR/layout-helper.py"
"$REAL_PYTHON" -m py_compile "$MOCK_DIR/layout-helper.py"

if [[ ${FAILURE:-} == symlink_swap ]]; then
  /bin/mkdir -p "$MOCK_DIR/remote-srv/apps"
  /bin/ln -s "$MOCK_DIR/outside-target" \
    "$MOCK_DIR/remote-srv/apps/website"
  printf '%s\n' swapped > "$MOCK_DIR/swap-attempted"
  echo 'error=managed_path_invalid' >&2
  exit 37
fi

case "${FAILURE:-}" in
  layout_install|layout_mode|layout_owner)
    exit 34
    ;;
  temp_marker|temp_marker_mode|marker_move)
    printf '%s\n' .layout-ready.tmp.fake > "$MOCK_DIR/temp-marker"
    : > "$MOCK_DIR/temp-marker"
    exit 35
    ;;
esac

cat > "$MOCK_DIR/metadata" <<'METADATA'
/srv/bootstrap|755|0:0
/srv/apps|755|0:0
/srv/apps/website|750|1000:1000
/srv/apps/website/shared|750|1000:1000
/srv/apps/website/shared/db|750|1000:1000
/srv/backups|755|0:0
/srv/backups/website|750|0:0
/srv/bootstrap/.layout-ready|644|0:0
METADATA
printf '%s\n' ready > "$MOCK_DIR/marker"
: > "$MOCK_DIR/temp-marker"
PYTHON

cat > "$temp_dir/remote-bin/install" <<'INSTALL'
#!/usr/bin/env bash
set -euo pipefail

directory=0
mode=
owner=
group=
args=("$@")
index=0
while (( index < ${#args[@]} )); do
  case "${args[$index]}" in
    -d)
      directory=1
      ;;
    -m)
      ((index += 1))
      mode=${args[$index]#0}
      ;;
    -o)
      ((index += 1))
      owner=${args[$index]}
      [[ $owner == root ]] && owner=0
      ;;
    -g)
      ((index += 1))
      group=${args[$index]}
      [[ $group == root ]] && group=0
      ;;
  esac
  ((index += 1))
done

target=${args[${#args[@]}-1]}
printf 'install:%s\n' "$*" >> "$EVENT_LOG"

if (( directory )); then
  [[ ${FAILURE:-} != layout_install ]] || exit 34
  grep -Fv "$target|" "$MOCK_DIR/metadata" > "$MOCK_DIR/metadata.next" || true
  printf '%s|%s|%s:%s\n' "$target" "$mode" "$owner" "$group" >> "$MOCK_DIR/metadata.next"
  /bin/mv "$MOCK_DIR/metadata.next" "$MOCK_DIR/metadata"
else
  [[ ${FAILURE:-} != temp_marker ]] || exit 35
  if grep -Fq "$target|" "$MOCK_DIR/content"; then
    grep -Fv "$target|" "$MOCK_DIR/content" > "$MOCK_DIR/content.next" || true
    printf '%s|\n' "$target" >> "$MOCK_DIR/content.next"
    /bin/mv "$MOCK_DIR/content.next" "$MOCK_DIR/content"
  fi
  grep -Fv "$target|" "$MOCK_DIR/metadata" > "$MOCK_DIR/metadata.next" || true
  printf '%s|%s|%s:%s\n' "$target" "$mode" "$owner" "$group" >> "$MOCK_DIR/metadata.next"
  /bin/mv "$MOCK_DIR/metadata.next" "$MOCK_DIR/metadata"
fi
INSTALL

cat > "$temp_dir/remote-bin/stat" <<'STAT'
#!/usr/bin/env bash
set -euo pipefail

format=$2
target=${!#}
record=$(grep -F "$target|" "$MOCK_DIR/metadata" | tail -n 1)
mode=$(cut -d'|' -f2 <<<"$record")
owner=$(cut -d'|' -f3 <<<"$record")

if [[ ${FAILURE:-} == layout_mode && $target == "$APP_SHARED_ROOT" ]]; then
  mode=755
elif [[ ${FAILURE:-} == temp_marker_mode && $target == /srv/bootstrap/.layout-ready.tmp.mock ]]; then
  mode=600
fi

if [[ ${FAILURE:-} == layout_owner && $target == "$APP_SHARED_ROOT" ]]; then
  owner=0:0
fi

case "$format" in
  %a) echo "$mode" ;;
  %u:%g) echo "$owner" ;;
  *) exit 64 ;;
esac
STAT

cat > "$temp_dir/remote-bin/mktemp" <<'MKTEMP'
#!/usr/bin/env bash
set -euo pipefail
target=/srv/bootstrap/.layout-ready.tmp.mock
printf '%s\n' "$target" > "$MOCK_DIR/temp-marker"
grep -Fv "$target|" "$MOCK_DIR/metadata" > "$MOCK_DIR/metadata.next" || true
printf '%s|600|0:0\n' "$target" >> "$MOCK_DIR/metadata.next"
/bin/mv "$MOCK_DIR/metadata.next" "$MOCK_DIR/metadata"
echo "$target"
MKTEMP

cat > "$temp_dir/remote-bin/mv" <<'MV'
#!/usr/bin/env bash
set -euo pipefail
printf 'mv:%s\n' "$*" >> "$EVENT_LOG"

source_path=${@: -2:1}
target_path=${@: -1}
if [[ $target_path == /srv/bootstrap/.layout-ready ]]; then
  [[ ${FAILURE:-} != marker_move ]] || exit 36
  record=$(grep -F "$source_path|" "$MOCK_DIR/metadata" | tail -n 1)
  grep -Fv "$source_path|" "$MOCK_DIR/metadata" > "$MOCK_DIR/metadata.next" || true
  grep -Fv "$target_path|" "$MOCK_DIR/metadata.next" > "$MOCK_DIR/metadata.next2" || true
  printf '%s|%s\n' "$target_path" "${record#*|}" >> "$MOCK_DIR/metadata.next2"
  /bin/mv "$MOCK_DIR/metadata.next2" "$MOCK_DIR/metadata"
  printf '%s\n' ready > "$MOCK_DIR/marker"
  : > "$MOCK_DIR/temp-marker"
else
  /bin/mv "$source_path" "$target_path"
fi
MV

cat > "$temp_dir/remote-bin/rm" <<'RM'
#!/usr/bin/env bash
set -euo pipefail
target=${@: -1}
sentinel=/srv/apps/website/shared/sentinel
if [[ $sentinel == "$target" || $sentinel == "$target/"* ]]; then
  grep -Fv "$sentinel|" "$MOCK_DIR/content" > "$MOCK_DIR/content.next" || true
  /bin/mv "$MOCK_DIR/content.next" "$MOCK_DIR/content"
fi
RM

cat > "$temp_dir/remote-bin/truncate" <<'TRUNCATE'
#!/usr/bin/env bash
set -euo pipefail
target=${@: -1}
if grep -Fq "$target|" "$MOCK_DIR/content"; then
  grep -Fv "$target|" "$MOCK_DIR/content" > "$MOCK_DIR/content.next" || true
  printf '%s|\n' "$target" >> "$MOCK_DIR/content.next"
  /bin/mv "$MOCK_DIR/content.next" "$MOCK_DIR/content"
fi
TRUNCATE

cat > "$temp_dir/remote-bin/chown" <<'CHOWN'
#!/usr/bin/env bash
echo 'unexpected chown' >&2
exit 91
CHOWN

cat > "$temp_dir/remote-bin/chmod" <<'CHMOD'
#!/usr/bin/env bash
echo 'unexpected chmod' >&2
exit 92
CHMOD

chmod +x "$temp_dir/ssh" "$temp_dir/remote-bin/"*

reset_host() {
  : > "$temp_dir/metadata"
  : > "$temp_dir/marker"
  : > "$temp_dir/temp-marker"
  : > "$temp_dir/events"
  : > "$temp_dir/content"
  /bin/rm -rf "$temp_dir/remote-srv" "$temp_dir/outside-target"
  /bin/mkdir -p "$temp_dir/remote-srv" "$temp_dir/outside-target"
  rm -f "$temp_dir/docker-installed"
}

run_remote_preserving_host() {
  local name=$1 flag=$2
  shift 2

  local environment=(
    SSH_EXECUTE_REMOTE=1
    SSH_ARGS_FILE="$temp_dir/$name.args"
    SSH_STDIN_FILE="$temp_dir/$name.stdin"
    SSH_REMOTE_COMMAND_FILE="$temp_dir/$name.remote-command"
    REMOTE_BASH_ENV="$temp_dir/remote-bash-env"
    MOCK_DIR="$temp_dir"
    EVENT_LOG="$temp_dir/events"
    PATH="$temp_dir:$temp_dir/remote-bin:$PATH"
    KAMAL_HOST=host.example.test
    APP_SHARED_ROOT=/srv/apps/website/shared
    TEST_REGISTRY_SECRET=registry-secret-should-not-appear
    TEST_MASTER_SECRET=master-secret-should-not-appear
    REAL_PYTHON="$real_python"
  )

  if [[ $flag == __unset__ ]]; then
    env -u ALLOW_ROOT_DISK_STORAGE "$@" "${environment[@]}" \
      "$project_root/bin/bootstrap-kamal-host" > "$temp_dir/$name.output" 2>&1
  else
    env "$@" "${environment[@]}" ALLOW_ROOT_DISK_STORAGE="$flag" \
      "$project_root/bin/bootstrap-kamal-host" > "$temp_dir/$name.output" 2>&1
  fi
}

run_remote() {
  local name=$1
  shift
  reset_host
  run_remote_preserving_host "$name" "$@"
}

assert_no_mutation() {
  [[ ! -s $temp_dir/events ]] || fail "unexpected mutation: $(<"$temp_dir/events")"
  [[ ! -s $temp_dir/marker ]] || fail "unexpected ready marker"
}

assert_marker_absent() {
  [[ ! -s $temp_dir/marker ]] || fail "failure published the ready marker"
}

# Local validation happens before SSH.
if PATH="$temp_dir:$PATH" APP_SHARED_ROOT=/srv/apps/website/shared \
  "$project_root/bin/bootstrap-kamal-host" > "$temp_dir/missing-host.output" 2>&1; then
  fail "expected missing KAMAL_HOST to fail"
fi
assert_contains 'error=missing_kamal_host' "$temp_dir/missing-host.output"

if PATH="$temp_dir:$PATH" KAMAL_HOST=host.example.test \
  "$project_root/bin/bootstrap-kamal-host" > "$temp_dir/missing-root.output" 2>&1; then
  fail "expected missing APP_SHARED_ROOT to fail"
fi
assert_contains 'error=missing_app_shared_root' "$temp_dir/missing-root.output"

if PATH="$temp_dir:$PATH" KAMAL_HOST=host.example.test APP_SHARED_ROOT=/tmp/shared \
  "$project_root/bin/bootstrap-kamal-host" > "$temp_dir/invalid-root.output" 2>&1; then
  fail "expected invalid APP_SHARED_ROOT to fail"
fi
assert_contains 'error=invalid_app_shared_root' "$temp_dir/invalid-root.output"

for dot_segment in . ..; do
  if PATH="$temp_dir:$PATH" KAMAL_HOST=host.example.test \
    APP_SHARED_ROOT="/srv/apps/$dot_segment/shared" \
    "$project_root/bin/bootstrap-kamal-host" \
      > "$temp_dir/invalid-dot-root.output" 2>&1; then
    fail "expected dot-segment APP_SHARED_ROOT to fail"
  fi
  assert_contains 'error=invalid_app_shared_root' \
    "$temp_dir/invalid-dot-root.output"
done

injection_file="$temp_dir/injection-executed"
# shellcheck disable=SC2016
adversarial_roots=(
  '/srv/apps/has space/shared'
  '/srv/apps/$(touch${IFS}$INJECTION_FILE)/shared'
  '/srv/apps/`touch${IFS}$INJECTION_FILE`/shared'
  '/srv/apps/has"quote/shared'
  "/srv/apps/has'quote/shared"
  '/srv/apps/name;touch${IFS}$INJECTION_FILE/shared'
  '/srv/apps/.hidden/shared'
  '/srv/apps/hidden./shared'
  '/srv/apps/-leading/shared'
  '/srv/apps/trailing-/shared'
  '/srv/apps/_leading/shared'
  '/srv/apps/trailing_/shared'
)

adversarial_number=0
for adversarial_root in "${adversarial_roots[@]}"; do
  ((adversarial_number += 1))
  adversarial_args="$temp_dir/adversarial-$adversarial_number.args"
  if SSH_ARGS_FILE="$adversarial_args" \
    SSH_STDIN_FILE="$temp_dir/adversarial-$adversarial_number.stdin" \
    PATH="$temp_dir:$PATH" \
    INJECTION_FILE="$injection_file" \
    KAMAL_HOST=host.example.test \
    APP_SHARED_ROOT="$adversarial_root" \
    "$project_root/bin/bootstrap-kamal-host" \
      > "$temp_dir/adversarial-$adversarial_number.output" 2>&1; then
    fail "expected adversarial APP_SHARED_ROOT to fail: $adversarial_root"
  fi
  assert_contains 'error=invalid_app_shared_root' \
    "$temp_dir/adversarial-$adversarial_number.output"
  [[ ! -e $adversarial_args ]] ||
    fail "adversarial APP_SHARED_ROOT reached SSH: $adversarial_root"
  [[ ! -e $injection_file ]] ||
    fail "adversarial APP_SHARED_ROOT executed a command"
done

# SSH receives only the root destination, bash command, shared root, and normalized flag.
reset_host
SSH_ARGS_FILE="$temp_dir/capture.args" \
SSH_STDIN_FILE="$temp_dir/capture.stdin" \
PATH="$temp_dir:$PATH" \
KAMAL_HOST=host.example.test \
APP_SHARED_ROOT=/srv/apps/website/shared \
ALLOW_ROOT_DISK_STORAGE=true \
TEST_REGISTRY_SECRET=registry-secret-should-not-appear \
TEST_MASTER_SECRET=master-secret-should-not-appear \
  "$project_root/bin/bootstrap-kamal-host" > "$temp_dir/capture.output" 2>&1

diff -u <(printf '%s\n' \
  root@host.example.test bash -s -- /srv/apps/website/shared 0) \
  "$temp_dir/capture.args"

for capture in "$temp_dir/capture.args" "$temp_dir/capture.stdin" "$temp_dir/capture.output"; do
  assert_not_contains registry-secret-should-not-appear "$capture"
  assert_not_contains master-secret-should-not-appear "$capture"
done

# The remote script independently rejects an unsafe root before host inspection.
if env BASH_ENV="$temp_dir/remote-bash-env" \
  MOCK_DIR="$temp_dir" \
  PATH="$temp_dir/remote-bin:$PATH" \
  bash -s -- '/srv/apps/-unsafe/shared' 0 \
    < "$temp_dir/capture.stdin" > "$temp_dir/remote-invalid.output" 2>&1; then
  fail "expected remote APP_SHARED_ROOT validation to fail"
fi
assert_contains 'error=invalid_app_shared_root' "$temp_dir/remote-invalid.output"
assert_no_mutation

# Root-disk opt-in and all other preconditions run before mutation.
assert_failed_with same-fs-unset srv_not_separate_filesystem __unset__ SAME_FILESYSTEM=1
[[ $(sed -n '6p' "$temp_dir/same-fs-unset.args") == 0 ]] ||
  fail "unset root-disk opt-in was not forwarded as 0"
assert_no_mutation
assert_failed_with same-fs-invalid srv_not_separate_filesystem true SAME_FILESYSTEM=1
[[ $(sed -n '6p' "$temp_dir/same-fs-invalid.args") == 0 ]] ||
  fail "invalid root-disk opt-in was not normalized to 0"
assert_no_mutation
assert_failed_with same-fs-blank srv_not_separate_filesystem '' SAME_FILESYSTEM=1
[[ $(sed -n '6p' "$temp_dir/same-fs-blank.args") == 0 ]] ||
  fail "blank root-disk opt-in was not normalized to 0"
assert_no_mutation

run_remote same-fs-allowed 1 SAME_FILESYSTEM=1
[[ $(sed -n '6p' "$temp_dir/same-fs-allowed.args") == 1 ]] ||
  fail "exact root-disk opt-in was not forwarded as 1"
assert_contains \
  'warning=root_disk_storage_enabled data_will_not_survive_server_loss' \
  "$temp_dir/same-fs-allowed.output"
assert_contains 'host_bootstrap=ready' "$temp_dir/same-fs-allowed.output"

run_remote separate-fs __unset__
assert_contains 'host_bootstrap=ready' "$temp_dir/separate-fs.output"

assert_failed_with unsupported-os unsupported_host_os __unset__ REMOTE_OS=debian-12
assert_no_mutation
assert_failed_with missing-os-release unsupported_host_os __unset__ REMOTE_OS=missing
assert_no_mutation
assert_failed_with missing-srv-source srv_mount_source_unavailable __unset__ \
  FINDMNT_FAILURE=/srv
assert_no_mutation
assert_failed_with missing-root-source root_mount_source_unavailable __unset__ \
  FINDMNT_FAILURE=/
assert_no_mutation
assert_failed_with missing-apt host_command_missing __unset__ MISSING_COMMAND=apt-get
assert_no_mutation
assert_failed_with missing-systemctl host_command_missing __unset__ MISSING_COMMAND=systemctl
assert_no_mutation
assert_failed_with missing-python host_command_missing __unset__ MISSING_COMMAND=python3
assert_no_mutation

managed_paths=(
  /srv/bootstrap
  /srv/apps
  /srv/apps/website
  /srv/apps/website/shared
  /srv/apps/website/shared/db
  /srv/backups
  /srv/backups/website
)

case_number=0
for path in "${managed_paths[@]}"; do
  for kind in symlink file; do
    ((case_number += 1))
    assert_failed_with "invalid-path-$case_number" managed_path_invalid __unset__ \
      INVALID_PATH="$path" INVALID_KIND="$kind"
    assert_no_mutation
  done
done

for marker_kind in symlink directory; do
  assert_failed_with "invalid-marker-$marker_kind" layout_marker_invalid __unset__ \
    MARKER_KIND="$marker_kind"
  assert_no_mutation
done

# Docker installation and startup ordering.
run_remote docker-absent __unset__
[[ $(sed -n '1p' "$temp_dir/events") == 'apt-get::update' ]] ||
  fail "apt-get update was not first"
[[ $(sed -n '2p' "$temp_dir/events") == \
  'apt-get:noninteractive:install -y docker.io' ]] ||
  fail "docker.io install command was not second"
[[ $(sed -n '3p' "$temp_dir/events") == 'systemctl:enable --now docker' ]] ||
  fail "systemctl did not follow package installation"
[[ $(sed -n '4p' "$temp_dir/events") == 'docker:info' ]] ||
  fail "docker info did not follow systemctl"

run_remote docker-present __unset__ DOCKER_PRESENT=1
assert_not_contains 'apt-get:' "$temp_dir/events"
assert_contains 'systemctl:enable --now docker' "$temp_dir/events"
assert_contains 'docker:info' "$temp_dir/events"

# No first-run failure may publish readiness.
for failure in package_update package_install systemctl docker layout_install layout_mode layout_owner \
  temp_marker temp_marker_mode marker_move; do
  assert_failed_with "failure-$failure" "" __unset__ FAILURE="$failure"
  assert_marker_absent
  [[ ! -s $temp_dir/temp-marker ]] ||
    fail "$failure left a private temp marker"
done

# A package-time symlink swap must not reach or alter the outside target.
reset_host
printf '%s\n' keep-outside > "$temp_dir/outside-target/sentinel"
chmod 0700 "$temp_dir/outside-target"
outside_mode_before=$(stat -f '%Lp' "$temp_dir/outside-target" 2>/dev/null ||
  stat -c '%a' "$temp_dir/outside-target")
if run_remote_preserving_host symlink-swap __unset__ FAILURE=symlink_swap; then
  fail "expected package-time symlink swap to fail"
fi
assert_contains 'error=managed_path_invalid' "$temp_dir/symlink-swap.output"
assert_contains swapped "$temp_dir/swap-attempted"
[[ -L $temp_dir/remote-srv/apps/website ]] ||
  fail "fake host did not perform the deterministic symlink swap"
assert_contains keep-outside "$temp_dir/outside-target/sentinel"
outside_mode_after=$(stat -f '%Lp' "$temp_dir/outside-target" 2>/dev/null ||
  stat -c '%a' "$temp_dir/outside-target")
[[ $outside_mode_after == "$outside_mode_before" ]] ||
  fail "descriptor helper changed outside-target mode"
assert_marker_absent
[[ ! -s $temp_dir/temp-marker ]] ||
  fail "symlink swap left a private temp marker"

# Successful layout is exact, and both runs preserve modeled content inside shared.
reset_host
printf '%s\n' '/srv/apps/website/shared/sentinel|keep-me' > "$temp_dir/content"
run_remote_preserving_host first-success __unset__
expected_metadata="$temp_dir/expected-metadata"
cat > "$expected_metadata" <<'METADATA'
/srv/bootstrap|755|0:0
/srv/apps|755|0:0
/srv/apps/website|750|1000:1000
/srv/apps/website/shared|750|1000:1000
/srv/apps/website/shared/db|750|1000:1000
/srv/backups|755|0:0
/srv/backups/website|750|0:0
/srv/bootstrap/.layout-ready|644|0:0
METADATA
diff -u "$expected_metadata" "$temp_dir/metadata"
[[ -s $temp_dir/marker ]] || fail "success did not publish the ready marker"
assert_contains 'host_bootstrap=ready' "$temp_dir/first-success.output"
assert_contains 'next=bin/setup-kamal' "$temp_dir/first-success.output"
assert_contains '/srv/apps/website/shared/sentinel|keep-me' "$temp_dir/content"

: > "$temp_dir/events"
run_remote_preserving_host second-success __unset__
assert_contains '/srv/apps/website/shared/sentinel|keep-me' "$temp_dir/content"
diff -u "$expected_metadata" "$temp_dir/metadata"
assert_not_contains 'apt-get:' "$temp_dir/events"
assert_contains 'host_bootstrap=ready' "$temp_dir/second-success.output"

# Keep the script narrowly scoped.
assert_not_contains 'ufw' "$temp_dir/capture.stdin"
assert_not_contains 'iptables' "$temp_dir/capture.stdin"
assert_not_contains 'docker prune' "$temp_dir/capture.stdin"
assert_not_contains 'chown -R' "$temp_dir/capture.stdin"
assert_not_contains 'chmod -R' "$temp_dir/capture.stdin"
assert_not_contains 'resolv' "$temp_dir/capture.stdin"
assert_not_contains 'hostname' "$temp_dir/capture.stdin"
assert_not_contains 'kamal deploy' "$temp_dir/capture.stdin"
assert_not_contains 'bin/deploy' "$temp_dir/capture.stdin"
grep -Fq 'os.O_DIRECTORY' "$temp_dir/capture.stdin" ||
  fail "descriptor helper does not require directories"
grep -Fq 'os.O_NOFOLLOW' "$temp_dir/capture.stdin" ||
  fail "descriptor helper follows symlinks"
grep -Fq 'dir_fd=' "$temp_dir/capture.stdin" ||
  fail "descriptor helper does not use relative operations"
grep -Fq 'os.fchmod' "$temp_dir/capture.stdin" ||
  fail "descriptor helper does not set mode through held descriptors"
grep -Fq 'os.fchown' "$temp_dir/capture.stdin" ||
  fail "descriptor helper does not set ownership through held descriptors"
grep -Fq 'os.fstat' "$temp_dir/capture.stdin" ||
  fail "descriptor helper does not verify through held descriptors"
grep -Fq 'os.unlink(marker_temp, dir_fd=bootstrap_fd)' "$temp_dir/capture.stdin" ||
  fail "descriptor helper does not safely clean private temp markers"
