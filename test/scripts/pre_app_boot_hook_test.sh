#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

cat > "$temp_dir/ssh" <<'SSH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$SSH_ARGS_FILE"
cat > "$SSH_STDIN_FILE"
SSH
chmod +x "$temp_dir/ssh"

SSH_ARGS_FILE="$temp_dir/args" \
SSH_STDIN_FILE="$temp_dir/stdin" \
PATH="$temp_dir:$PATH" \
KAMAL_HOST=shared-kamal-01 \
APP_SHARED_ROOT=/srv/apps/website/shared \
"$project_root/.kamal/hooks/pre-app-boot"

grep -Fx 'root@shared-kamal-01' "$temp_dir/args"
grep -Fx '/srv/apps/website/shared' "$temp_dir/args"
grep -F 'install -d -m 0750 -o 1000 -g 1000' "$temp_dir/stdin"
grep -F "stat -c '%u:%g' -- \"\$app_shared_root\"" "$temp_dir/stdin"
grep -F "stat -c '%u:%g' -- \"\$app_shared_root/db\"" "$temp_dir/stdin"
grep -F "rm -f -- \"\$app_shared_root/.web-ready\"" "$temp_dir/stdin"
if grep -Eiq 'sqlite|hatchbox' "$temp_dir/stdin"; then
  echo 'pre-app-boot must not touch SQLite data or Hatchbox configuration' >&2
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
