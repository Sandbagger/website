#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

assert_absent() {
  if grep -Fq -- "$1" "$2"; then
    echo 'unexpected secret disclosure' >&2
    exit 1
  fi
}

assert_no_secrets() {
  assert_absent 'registry-secret-should-not-appear' "$1"
  assert_absent 'master-key-secret-should-not-appear' "$1"
}

assert_no_external_commands() {
  [[ ! -e "$1" || ! -s "$1" ]]
}

cat > "$temp_dir/bundle" <<'BUNDLE'
#!/usr/bin/env bash
printf 'bundle:%s\n' "$*" >> "$EVENTS_FILE"
BUNDLE
chmod +x "$temp_dir/bundle"

cat > "$temp_dir/ssh" <<'SSH'
#!/usr/bin/env bash
ssh_stdin="${EVENTS_FILE}.ssh-stdin"
cat > "$ssh_stdin"
if grep -Fq "echo 'host_bootstrap=ready'" "$ssh_stdin"; then
  printf 'bootstrap-ssh:%s\n' "$*" >> "$EVENTS_FILE"
  if [[ -n "${BOOTSTRAP_FAILURE:-}" ]]; then
    echo "error=$BOOTSTRAP_FAILURE" >&2
    exit 7
  fi
  echo 'host_bootstrap=ready'
  echo 'next=bin/setup-kamal'
  exit 0
fi
printf 'ssh:%s\n' "$*" >> "$EVENTS_FILE"
if [[ -n "${SSH_FAILURE:-}" ]]; then
  echo "error=$SSH_FAILURE" >&2
  exit 1
fi
if [[ "${SSH_WARNING:-}" == 1 ]]; then
  echo 'warning=root_disk_storage_enabled data_will_not_survive_server_loss' >&2
fi
SSH
chmod +x "$temp_dir/ssh"

cat > "$temp_dir/valid.env" <<'ENV'
KAMAL_HOST=hetzner.example.test
APP_SHARED_ROOT=/srv/apps/website/shared
KAMAL_REGISTRY_PASSWORD=registry-secret-should-not-appear
RAILS_MASTER_KEY=master-key-secret-should-not-appear
ENV
chmod 600 "$temp_dir/valid.env"

missing_env_file="$temp_dir/missing.env.deploy"

if EVENTS_FILE="$temp_dir/missing_env.events" \
  DEPLOY_ENV_FILE="$missing_env_file" \
  PATH="$temp_dir:$PATH" \
  "$project_root/bin/setup-kamal" >"$temp_dir/missing_env.output" 2>&1; then
  echo 'expected missing deploy environment invocation to fail' >&2
  exit 1
fi

grep -Fx "error=missing_env_file path=$missing_env_file" "$temp_dir/missing_env.output"
grep -Fx 'hint=dotfiles-hetzner-tf handoff website --format env > .env.deploy' "$temp_dir/missing_env.output"
assert_no_secrets "$temp_dir/missing_env.output"
assert_no_external_commands "$temp_dir/missing_env.events"

cat > "$temp_dir/missing_secret.env" <<'ENV'
KAMAL_HOST=hetzner.example.test
APP_SHARED_ROOT=/srv/apps/website/shared
KAMAL_REGISTRY_PASSWORD=
RAILS_MASTER_KEY=master-key-secret-should-not-appear
ENV
chmod 600 "$temp_dir/missing_secret.env"

if EVENTS_FILE="$temp_dir/missing_secret.events" \
  DEPLOY_ENV_FILE="$temp_dir/missing_secret.env" \
  PATH="$temp_dir:$PATH" \
  "$project_root/bin/setup-kamal" >"$temp_dir/missing_secret.output" 2>&1; then
  echo 'expected missing secret invocation to fail' >&2
  exit 1
fi

grep -Fx 'error=missing_vars vars=KAMAL_REGISTRY_PASSWORD' "$temp_dir/missing_secret.output"
grep -Fx 'hint=set KAMAL_REGISTRY_PASSWORD from the GitHub Packages token in 1Password' "$temp_dir/missing_secret.output"
assert_no_secrets "$temp_dir/missing_secret.output"
assert_no_external_commands "$temp_dir/missing_secret.events"

cat > "$temp_dir/template_host.env" <<'ENV'
KAMAL_HOST=shared-kamal-01
APP_SHARED_ROOT=/srv/apps/website/shared
KAMAL_REGISTRY_PASSWORD=registry-secret-should-not-appear
RAILS_MASTER_KEY=master-key-secret-should-not-appear
ENV
chmod 600 "$temp_dir/template_host.env"

if EVENTS_FILE="$temp_dir/template_host.events" \
  DEPLOY_ENV_FILE="$temp_dir/template_host.env" \
  PATH="$temp_dir:$PATH" \
  "$project_root/bin/setup-kamal" >"$temp_dir/template_host.output" 2>&1; then
  echo 'expected template-host invocation to fail' >&2
  exit 1
fi

grep -Fx 'error=template_kamal_host host=shared-kamal-01' "$temp_dir/template_host.output"
grep -Fx 'hint=replace KAMAL_HOST with the Hetzner host/IP from the handoff' "$temp_dir/template_host.output"
assert_no_secrets "$temp_dir/template_host.output"
assert_no_external_commands "$temp_dir/template_host.events"

cp "$temp_dir/valid.env" "$temp_dir/insecure.env"
chmod 0644 "$temp_dir/insecure.env"

if EVENTS_FILE="$temp_dir/insecure.events" \
  DEPLOY_ENV_FILE="$temp_dir/insecure.env" \
  PATH="$temp_dir:$PATH" \
  "$project_root/bin/setup-kamal" >"$temp_dir/insecure.output" 2>&1; then
  echo 'expected insecure deploy environment invocation to fail' >&2
  exit 1
fi

grep -Fx 'error=insecure_env_file_permissions' "$temp_dir/insecure.output"
grep -Fx 'hint=chmod 600 .env.deploy' "$temp_dir/insecure.output"
assert_no_secrets "$temp_dir/insecure.output"
assert_no_external_commands "$temp_dir/insecure.events"

if EVENTS_FILE="$temp_dir/bootstrap_insecure.events" \
  DEPLOY_ENV_FILE="$temp_dir/insecure.env" \
  PATH="$temp_dir:$PATH" \
  "$project_root/bin/setup-kamal" --bootstrap-host >"$temp_dir/bootstrap_insecure.output" 2>&1; then
  echo 'expected bootstrap with insecure deploy environment to fail' >&2
  exit 1
fi

grep -Fx 'error=insecure_env_file_permissions' "$temp_dir/bootstrap_insecure.output"
assert_no_secrets "$temp_dir/bootstrap_insecure.output"
assert_no_external_commands "$temp_dir/bootstrap_insecure.events"

if EVENTS_FILE="$temp_dir/preflight_failure.events" \
  SSH_FAILURE=bootstrap_layout_not_ready \
  DEPLOY_ENV_FILE="$temp_dir/valid.env" \
  PATH="$temp_dir:$PATH" \
  "$project_root/bin/setup-kamal" >"$temp_dir/preflight_failure.output" 2>&1; then
  echo 'expected preflight failure to stop setup' >&2
  exit 1
fi

grep -Fx 'error=bootstrap_layout_not_ready' "$temp_dir/preflight_failure.output"
grep -Fx 'error=preflight_ssh_failed' "$temp_dir/preflight_failure.output"
grep -Fx 'hint=run bin/setup-kamal --bootstrap-host to prepare this existing host' "$temp_dir/preflight_failure.output"
grep -Fx 'hint=repair the reported host prerequisite, then rerun bin/setup-kamal' "$temp_dir/preflight_failure.output"
grep -Fx 'ssh:root@hetzner.example.test bash -s -- /srv/apps/website/shared 0' "$temp_dir/preflight_failure.events"
assert_absent 'bundle:' "$temp_dir/preflight_failure.events"
assert_no_secrets "$temp_dir/preflight_failure.output"

if EVENTS_FILE="$temp_dir/unrelated_preflight_failure.events" \
  SSH_FAILURE=foreign_ingress_listener \
  DEPLOY_ENV_FILE="$temp_dir/valid.env" \
  PATH="$temp_dir:$PATH" \
  "$project_root/bin/setup-kamal" >"$temp_dir/unrelated_preflight_failure.output" 2>&1; then
  echo 'expected unrelated preflight failure to stop setup' >&2
  exit 1
fi

grep -Fx 'error=foreign_ingress_listener' "$temp_dir/unrelated_preflight_failure.output"
grep -Fx 'error=preflight_ssh_failed' "$temp_dir/unrelated_preflight_failure.output"
grep -Fx 'hint=repair the reported host prerequisite, then rerun bin/setup-kamal' "$temp_dir/unrelated_preflight_failure.output"
assert_absent 'hint=run bin/setup-kamal --bootstrap-host to prepare this existing host' "$temp_dir/unrelated_preflight_failure.output"
assert_absent 'bundle:' "$temp_dir/unrelated_preflight_failure.events"
assert_no_secrets "$temp_dir/unrelated_preflight_failure.output"

EVENTS_FILE="$temp_dir/no_args.events" \
DEPLOY_ENV_FILE="$temp_dir/valid.env" \
PATH="$temp_dir:$PATH" \
"$project_root/bin/setup-kamal" >"$temp_dir/no_args.output" 2>&1

diff -u \
  <(printf '%s\n' \
    'ssh:root@hetzner.example.test bash -s -- /srv/apps/website/shared 0' \
    'bundle:exec kamal version') \
  "$temp_dir/no_args.events"
grep -Fx 'Manually point DNS to the Hetzner host, then run bin/setup-kamal --apply.' "$temp_dir/no_args.output"
grep -Fx 'bin/setup-kamal --apply performs the first application deployment.' "$temp_dir/no_args.output"
assert_no_secrets "$temp_dir/no_args.output"
assert_no_secrets "$temp_dir/no_args.events"
assert_no_secrets "$temp_dir/no_args.events.ssh-stdin"

cp "$temp_dir/valid.env" "$temp_dir/root_disk.env"
printf '%s\n' 'ALLOW_ROOT_DISK_STORAGE=1' >> "$temp_dir/root_disk.env"
chmod 600 "$temp_dir/root_disk.env"

EVENTS_FILE="$temp_dir/root_disk_warning.events" \
SSH_WARNING=1 \
DEPLOY_ENV_FILE="$temp_dir/root_disk.env" \
PATH="$temp_dir:$PATH" \
"$project_root/bin/setup-kamal" >"$temp_dir/root_disk_warning.output" 2>&1

grep -Fx 'ssh:root@hetzner.example.test bash -s -- /srv/apps/website/shared 1' "$temp_dir/root_disk_warning.events"
grep -Fx 'warning=root_disk_storage_enabled data_will_not_survive_server_loss' "$temp_dir/root_disk_warning.output"
assert_no_secrets "$temp_dir/root_disk_warning.output"
assert_no_secrets "$temp_dir/root_disk_warning.events"
assert_no_secrets "$temp_dir/root_disk_warning.events.ssh-stdin"

EVENTS_FILE="$temp_dir/bootstrap.events" \
DEPLOY_ENV_FILE="$temp_dir/valid.env" \
PATH="$temp_dir:$PATH" \
"$project_root/bin/setup-kamal" --bootstrap-host >"$temp_dir/bootstrap.output" 2>&1

grep -Fx 'bootstrap-ssh:root@hetzner.example.test bash -s -- /srv/apps/website/shared 0' "$temp_dir/bootstrap.events"
[[ $(wc -l < "$temp_dir/bootstrap.events") -eq 1 ]]
grep -Fx 'host_bootstrap=ready' "$temp_dir/bootstrap.output"
grep -Fx 'next=bin/setup-kamal' "$temp_dir/bootstrap.output"
assert_absent 'bundle:' "$temp_dir/bootstrap.events"
assert_no_secrets "$temp_dir/bootstrap.output"
assert_no_secrets "$temp_dir/bootstrap.events"
assert_no_secrets "$temp_dir/bootstrap.events.ssh-stdin"

set +e
EVENTS_FILE="$temp_dir/bootstrap_failure.events" \
BOOTSTRAP_FAILURE=host_command_missing \
DEPLOY_ENV_FILE="$temp_dir/valid.env" \
PATH="$temp_dir:$PATH" \
"$project_root/bin/setup-kamal" --bootstrap-host >"$temp_dir/bootstrap_failure.output" 2>&1
bootstrap_failure_status=$?
set -e

[[ $bootstrap_failure_status -eq 7 ]]
grep -Fx 'error=host_command_missing' "$temp_dir/bootstrap_failure.output"
[[ $(wc -l < "$temp_dir/bootstrap_failure.events") -eq 1 ]]
assert_absent 'bundle:' "$temp_dir/bootstrap_failure.events"
assert_absent 'host_bootstrap=ready' "$temp_dir/bootstrap_failure.output"
assert_absent 'next=bin/setup-kamal' "$temp_dir/bootstrap_failure.output"
assert_no_secrets "$temp_dir/bootstrap_failure.output"
assert_no_secrets "$temp_dir/bootstrap_failure.events"
assert_no_secrets "$temp_dir/bootstrap_failure.events.ssh-stdin"

EVENTS_FILE="$temp_dir/apply.events" \
DEPLOY_ENV_FILE="$temp_dir/valid.env" \
PATH="$temp_dir:$PATH" \
"$project_root/bin/setup-kamal" --apply >"$temp_dir/apply.output" 2>&1

diff -u \
  <(printf '%s\n' \
    'ssh:root@hetzner.example.test bash -s -- /srv/apps/website/shared 0' \
    'bundle:exec kamal version' \
    'ssh:root@hetzner.example.test bash -s -- /srv/apps/website/shared 0' \
    'bundle:exec kamal version' \
    'bundle:exec kamal setup') \
  "$temp_dir/apply.events"
grep -Fx 'About to perform the first application deployment with Kamal.' "$temp_dir/apply.output"
grep -Fx 'Later releases use bin/deploy.' "$temp_dir/apply.output"
assert_no_secrets "$temp_dir/apply.output"
assert_no_secrets "$temp_dir/apply.events"
assert_no_secrets "$temp_dir/apply.events.ssh-stdin"

invalid_commands=(
  'deploy'
  '--bootstrap-host extra'
  '--apply extra'
)
for invalid_command in "${invalid_commands[@]}"; do
  read -r -a invalid_args <<< "$invalid_command"
  output_name=${invalid_command// /_}
  if EVENTS_FILE="$temp_dir/$output_name.events" \
    DEPLOY_ENV_FILE="$temp_dir/valid.env" \
    PATH="$temp_dir:$PATH" \
    "$project_root/bin/setup-kamal" "${invalid_args[@]}" >"$temp_dir/$output_name.output" 2>&1; then
    echo "expected invalid invocation to fail: $invalid_command" >&2
    exit 1
  fi

  grep -Fx 'usage: bin/setup-kamal [--bootstrap-host|--apply]' "$temp_dir/$output_name.output"
  assert_no_secrets "$temp_dir/$output_name.output"
  assert_no_external_commands "$temp_dir/$output_name.events"
done
