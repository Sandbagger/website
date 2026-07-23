#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

cat > "$temp_dir/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail

case "$1:$2" in
  image:inspect)
    exit 0
    ;;
  run:--rm)
    printf 'master_key=%s\n' "${RAILS_MASTER_KEY:+present}" > "$DOCKER_RESULT"
    printf 'secret_key_base=%s\n' "${SECRET_KEY_BASE:+present}" >> "$DOCKER_RESULT"
    printf 'dummy_secret_key_base=%s\n' "${SECRET_KEY_BASE_DUMMY:+present}" >> "$DOCKER_RESULT"
    printf '%s\n' "$@" >> "$DOCKER_ARGS"
    ;;
  *)
    printf 'unexpected docker invocation: %s\n' "$*" >&2
    exit 64
    ;;
esac
DOCKER
chmod +x "$temp_dir/docker"

DOCKER_ARGS="$temp_dir/docker-args" \
DOCKER_RESULT="$temp_dir/docker-result" \
PATH="$temp_dir:$PATH" \
RAILS_MASTER_KEY=test-master-key \
"$project_root/bin/run-production-image"

grep -Fx 'master_key=present' "$temp_dir/docker-result"
grep -Fx 'secret_key_base=present' "$temp_dir/docker-result"
grep -Fx 'dummy_secret_key_base=' "$temp_dir/docker-result"
grep -Fx -- '--init' "$temp_dir/docker-args"
grep -Fx -- '--name' "$temp_dir/docker-args"
grep -Fx 'website-local' "$temp_dir/docker-args"
grep -Fx -- '-p' "$temp_dir/docker-args"
grep -Fx '3000:3000' "$temp_dir/docker-args"
grep -Fx 'website-kamal-cutover:native' "$temp_dir/docker-args"
grep -Fx 'bin/run-production-image' "$project_root/.dockerignore"

DOCKER_ARGS="$temp_dir/docker-args-from-file" \
DOCKER_RESULT="$temp_dir/docker-result-from-file" \
PATH="$temp_dir:$PATH" \
"$project_root/bin/run-production-image"

grep -Fx 'master_key=present' "$temp_dir/docker-result-from-file"
