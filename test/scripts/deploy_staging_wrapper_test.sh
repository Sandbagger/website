#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

cat > "$temp_dir/bundle" <<'BUNDLE'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$BUNDLE_ARGS_FILE"
BUNDLE
chmod +x "$temp_dir/bundle"

cat > "$temp_dir/staging.env" <<'ENV'
KAMAL_HOST=shared-kamal-01
APP_SHARED_ROOT=/srv/apps/website-staging/shared
ENV

BUNDLE_ARGS_FILE="$temp_dir/bundle-args" \
DEPLOY_ENV_FILE="$temp_dir/staging.env" \
PATH="$temp_dir:$PATH" \
"$project_root/bin/deploy" staging config

grep -Fx 'exec kamal version' "$temp_dir/bundle-args"
grep -Fx 'exec kamal -d staging config' "$temp_dir/bundle-args"
