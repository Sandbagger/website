#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

cat > "$temp_dir/ssh" <<'SSH'
#!/usr/bin/env bash
if [[ -n "${KAMAL_REGISTRY_PASSWORD+x}" || -n "${RAILS_MASTER_KEY+x}" ]]; then
  echo 'ssh inherited deployment secrets' >&2
  exit 65
fi
printf '%s\n' "$@" > "$SSH_ARGS_FILE"
cat > "$SSH_STDIN_FILE"
SSH
chmod +x "$temp_dir/ssh"

SSH_ARGS_FILE="$temp_dir/args" \
SSH_STDIN_FILE="$temp_dir/stdin" \
PATH="$temp_dir:$PATH" \
KAMAL_HOST=shared-kamal-01 \
APP_SHARED_ROOT=/srv/apps/website/shared \
KAMAL_REGISTRY_PASSWORD=registry-secret-should-not-appear \
RAILS_MASTER_KEY=rails-secret-should-not-appear \
"$project_root/.kamal/hooks/pre-app-boot"

grep -Fx 'root@shared-kamal-01' "$temp_dir/args"
grep -Fx '/srv/apps/website/shared' "$temp_dir/args"
grep -F 'O_DIRECTORY' "$temp_dir/stdin"
grep -F 'O_NOFOLLOW' "$temp_dir/stdin"
grep -F 'dir_fd=' "$temp_dir/stdin"
grep -F 'os.fchown' "$temp_dir/stdin"
grep -F 'os.fchmod' "$temp_dir/stdin"
grep -F 'st_ino' "$temp_dir/stdin"
grep -F 'open_existing_directory(srv_fd, "apps")' "$temp_dir/stdin"
grep -F 'open_directory(apps_fd, app_name' "$temp_dir/stdin"
grep -F 'open_directory(app_fd, "shared"' "$temp_dir/stdin"
grep -F 'open_directory(shared_fd, "db"' "$temp_dir/stdin"
# shellcheck disable=SC2016
grep -F 'run_app_layout_helper /srv "$app_name" 1000 1000' "$temp_dir/stdin"
if grep -Fq 'install -d' "$temp_dir/stdin"; then
  echo 'pre-app-boot must not rely on install pathname traversal' >&2
  exit 1
fi
if grep -Eiq 'sqlite|hatchbox|web-ready' "$temp_dir/stdin"; then
  echo 'pre-app-boot must not touch SQLite data, readiness markers, or Hatchbox configuration' >&2
  exit 1
fi

rm -f "$temp_dir/args"
if SSH_ARGS_FILE="$temp_dir/args" \
  SSH_STDIN_FILE="$temp_dir/stdin" \
  PATH="$temp_dir:$PATH" \
  KAMAL_HOST=shared-kamal-01 \
  APP_SHARED_ROOT=/tmp/shared \
  "$project_root/.kamal/hooks/pre-app-boot" >"$temp_dir/invalid-path.out" 2>&1; then
  echo 'expected invalid APP_SHARED_ROOT to fail' >&2
  exit 1
fi
test ! -e "$temp_dir/args"

unsafe_names=(
  '/srv/apps/-leading/shared'
  '/srv/apps/trailing-/shared'
  '/srv/apps/.hidden/shared'
  '/srv/apps/name;touch/shared'
  '/srv/apps/has space/shared'
)
for unsafe_root in "${unsafe_names[@]}"; do
  rm -f "$temp_dir/args"
  if SSH_ARGS_FILE="$temp_dir/args" \
    SSH_STDIN_FILE="$temp_dir/stdin" \
    PATH="$temp_dir:$PATH" \
    KAMAL_HOST=shared-kamal-01 \
    APP_SHARED_ROOT="$unsafe_root" \
    "$project_root/.kamal/hooks/pre-app-boot" \
      >"$temp_dir/unsafe-name.out" 2>&1; then
    echo "expected unsafe app root to fail: $unsafe_root" >&2
    exit 1
  fi
  test ! -e "$temp_dir/args"
done

python_helper="$temp_dir/app-layout-helper.py"
sed -n "/^import os$/,/^PYTHON$/p" "$temp_dir/stdin" |
  sed '$d' > "$python_helper"
runtime_root="$temp_dir/runtime-srv"
mkdir -p "$runtime_root/apps"
python3 "$python_helper" "$runtime_root" website "$(id -u)" "$(id -g)"

for relative_path in apps apps/website apps/website/shared \
  apps/website/shared/db; do
  test -d "$runtime_root/$relative_path"
done
test "$(stat -f '%Lp' "$runtime_root/apps/website" 2>/dev/null ||
  stat -c '%a' "$runtime_root/apps/website")" = 750

outside="$temp_dir/outside"
mkdir "$outside"
rm -rf "$runtime_root/apps/website"
ln -s "$outside" "$runtime_root/apps/website"
if python3 "$python_helper" "$runtime_root" website "$(id -u)" "$(id -g)" \
  >"$temp_dir/helper-symlink.out" 2>&1; then
  echo 'expected descriptor helper to reject a symlinked app root' >&2
  exit 1
fi
test ! -e "$outside/shared"
