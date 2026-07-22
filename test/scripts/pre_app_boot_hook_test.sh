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
