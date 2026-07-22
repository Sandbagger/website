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

SSH_ARGS_FILE="$temp_dir/success-args" \
SSH_STDIN_FILE="$temp_dir/success-stdin" \
PATH="$temp_dir:$PATH" \
KAMAL_HOST=shared-kamal-01 \
APP_SHARED_ROOT=/srv/apps/website/shared \
"$project_root/.kamal/hooks/pre-deploy"

grep -Fx 'root@shared-kamal-01' "$temp_dir/success-args"
grep -F 'bootstrap_layout_not_ready' "$temp_dir/success-stdin"
grep -F "exec \"\$repo_root/bin/deploy-preflight\"" "$project_root/.kamal/hooks/pre-deploy"

mkdir "$temp_dir/failure-bin"
cat > "$temp_dir/failure-bin/ssh" <<'SSH'
#!/usr/bin/env bash
echo 'error=preflight_transport_failed' >&2
exit 42
SSH
chmod +x "$temp_dir/failure-bin/ssh"

if PATH="$temp_dir/failure-bin:$PATH" \
  KAMAL_HOST=shared-kamal-01 \
  APP_SHARED_ROOT=/srv/apps/website/shared \
  PRE_DEPLOY_SECRET=should-not-appear \
  "$project_root/.kamal/hooks/pre-deploy" >"$temp_dir/failure.out" 2>&1; then
  echo 'expected preflight failure to propagate' >&2
  exit 1
fi

grep -Fx 'error=preflight_transport_failed' "$temp_dir/failure.out"
if grep -F 'should-not-appear' "$temp_dir/failure.out"; then
  echo 'hook exposed a secret' >&2
  exit 1
fi
