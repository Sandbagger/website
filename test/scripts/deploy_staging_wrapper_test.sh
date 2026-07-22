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

cat > "$temp_dir/staging.env" <<'ENV'
KAMAL_HOST=shared-kamal-01
APP_SHARED_ROOT=/srv/apps/website-staging/shared
ENV

EVENTS_FILE="$temp_dir/events" \
DEPLOY_ENV_FILE="$temp_dir/staging.env" \
PATH="$temp_dir:$PATH" \
"$project_root/bin/deploy" staging config

grep -Fx 'ssh:root@shared-kamal-01 bash -s -- /srv/apps/website-staging/shared' "$temp_dir/events"
grep -Fx 'bundle:exec kamal version' "$temp_dir/events"
grep -Fx 'bundle:exec kamal -d staging config' "$temp_dir/events"

preflight_line=$(grep -n '^ssh:' "$temp_dir/events" | cut -d: -f1)
version_line=$(grep -n '^bundle:exec kamal version$' "$temp_dir/events" | cut -d: -f1)
destination_line=$(grep -n '^bundle:exec kamal -d staging config$' "$temp_dir/events" | cut -d: -f1)
(( preflight_line < version_line ))
(( preflight_line < destination_line ))
