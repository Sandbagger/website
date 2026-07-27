# Root-Disk Kamal Host Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permit the existing single-disk Hetzner server to pass Kamal storage checks only with an explicit opt-in, and provide a guarded, idempotent command that bootstraps its host layout.

**Architecture:** Keep `bin/deploy-preflight` fail-closed and forward only the exact root-disk opt-in to its remote check. Add a focused `bin/bootstrap-kamal-host` script for the mutating Ubuntu host setup, while `bin/setup-kamal` remains the user-facing dispatcher for validation, bootstrap, and first deployment. Stub all remote commands in shell tests so implementation is verified without touching the live host.

**Tech Stack:** Bash, SSH, Ubuntu 22.04 `apt-get`/systemd, Docker, Kamal 2, Minitest/Rails verification

---

## File Structure

- Modify `bin/deploy-preflight`: validate and forward the opt-in; permit a shared root filesystem only for the exact value `1`; emit the risk warning.
- Modify `test/scripts/deploy_preflight_test.sh`: cover default rejection, exact opt-in acceptance, invalid values, separate-volume behavior, and argument secrecy.
- Create `bin/bootstrap-kamal-host`: perform the guarded, idempotent remote Ubuntu/Docker/layout bootstrap.
- Create `test/scripts/bootstrap_kamal_host_test.sh`: simulate the remote host and assert ordering, type safety, package behavior, layout, marker handling, and idempotence.
- Modify `bin/setup-kamal`: add `--bootstrap-host` and next-step guidance while preserving default validation and `--apply`.
- Modify `test/scripts/setup_kamal_test.sh`: cover dispatch, guidance, argument forwarding, failures, and secret non-disclosure.
- Modify `.env.deploy.example` and `.env.deploy.staging.example`: document the disabled-by-default storage exception.
- Modify `docs/DEPLOY.md`, `docs/MIGRATION_FROM_HATCHBOX.md`, `config/deploy.yml`, and `CLAUDE.md`: align active operational guidance and code comments with the explicit exception.

### Task 1: Fail-Closed Root-Disk Preflight Opt-In

**Files:**
- Modify: `test/scripts/deploy_preflight_test.sh`
- Modify: `bin/deploy-preflight`

- [ ] **Step 1: Write failing preflight tests**

Extend `run_preflight` and `run_remote_failure_case` so they can set or unset
`ALLOW_ROOT_DISK_STORAGE`. Add these cases:

```bash
# Same filesystem remains rejected when unset.
run_remote_failure_case same_mount srv_not_separate_filesystem

# Invalid values also remain rejected.
ALLOW_ROOT_DISK_STORAGE=true \
  run_remote_failure_case same_mount srv_not_separate_filesystem

# Exact opt-in permits root-disk storage and emits a warning.
SSH_EXECUTE_REMOTE=1 \
REMOTE_BASH_ENV="$temp_dir/remote-bash-env" \
PREFLIGHT_STATE=same_mount \
ALLOW_ROOT_DISK_STORAGE=1 \
PATH="$temp_dir:$temp_dir/remote-bin:$PATH" \
KAMAL_HOST=shared-kamal-01 \
APP_SHARED_ROOT=/srv/apps/website/shared \
"$project_root/bin/deploy-preflight" >"$temp_dir/root-disk.out" 2>&1

grep -Fx \
  'warning=root_disk_storage_enabled data_will_not_survive_server_loss' \
  "$temp_dir/root-disk.out"
```

Assert the captured SSH arguments end with:

```text
/srv/apps/website/shared
0
```

when the variable is unset, and end with `1` only for the exact opt-in. Assert
the registry and Rails test-secret fixtures never appear in SSH arguments,
stdin, or output. Keep the existing separate-filesystem success case without
requiring the opt-in.

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
bash -n bin/deploy-preflight test/scripts/deploy_preflight_test.sh
bash test/scripts/deploy_preflight_test.sh
```

Expected: the root-disk success assertion fails because preflight still
unconditionally emits `error=srv_not_separate_filesystem`.

- [ ] **Step 3: Implement exact opt-in forwarding**

In `bin/deploy-preflight`, normalize locally without accepting truthy aliases:

```bash
allow_root_disk_storage=0
if [[ "${ALLOW_ROOT_DISK_STORAGE:-}" == '1' ]]; then
  allow_root_disk_storage=1
fi
```

Pass it after `APP_SHARED_ROOT`:

```bash
ssh "root@$KAMAL_HOST" bash -s -- \
  "$APP_SHARED_ROOT" "$allow_root_disk_storage"
```

In the remote script:

```bash
app_shared_root="$1"
allow_root_disk_storage="$2"

srv_source=$(findmnt -n -o SOURCE --target /srv) ||
  fail srv_mount_source_unavailable
root_source=$(findmnt -n -o SOURCE --target /) ||
  fail root_mount_source_unavailable

if [[ "$srv_source" == "$root_source" ]]; then
  [[ "$allow_root_disk_storage" == '1' ]] ||
    fail srv_not_separate_filesystem
  echo \
    'warning=root_disk_storage_enabled data_will_not_survive_server_loss' \
    >&2
fi
```

Do not alter marker, ownership, symlink, Docker, or ingress checks.

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

```bash
bash -n bin/deploy-preflight test/scripts/deploy_preflight_test.sh
bash test/scripts/deploy_preflight_test.sh
```

Expected: exit 0, with all old failure cases and new opt-in cases passing.

- [ ] **Step 5: Commit**

```bash
git add bin/deploy-preflight test/scripts/deploy_preflight_test.sh
git commit -m "feat(deploy): Guard root-disk storage opt-in"
```

### Task 2: Idempotent Existing-Host Bootstrap

**Files:**
- Create: `test/scripts/bootstrap_kamal_host_test.sh`
- Create: `bin/bootstrap-kamal-host`

- [ ] **Step 1: Write the failing bootstrap harness**

Create a shell test that places stub implementations of `ssh`, `findmnt`,
`apt-get`, `systemctl`, `docker`, `install`, `chown`, `chmod`, and `touch`
ahead of `PATH`. The SSH stub must execute remote stdin locally with positional
arguments and a temporary fake filesystem state.

Cover the following cases:

```text
same filesystem + unset opt-in -> srv_not_separate_filesystem, no mutation
same filesystem + invalid opt-in -> srv_not_separate_filesystem, no mutation
same filesystem + exact 1 -> success plus root-disk risk warning
separate filesystem + unset opt-in -> success
unsupported OS -> unsupported_host_os, no mutation
managed symlink/non-directory -> managed_path_invalid, no mutation
Docker absent -> apt-get update/install, then systemctl and docker info
Docker present -> no apt-get, but systemctl and docker info still run
package/systemctl/docker/layout ownership or mode failure -> no ready marker
successful run -> exact types, modes, and owners from the spec
second successful run -> existing sentinel file under shared is preserved
existing symlink marker -> rejected rather than followed
```

Also assert SSH receives only:

```text
root@shared-kamal-01 bash -s -- /srv/apps/website/shared 0
```

or the final `1`, and never receives registry or Rails secrets.

- [ ] **Step 2: Run the new test and verify it fails**

Run:

```bash
bash test/scripts/bootstrap_kamal_host_test.sh
```

Expected: fail because `bin/bootstrap-kamal-host` does not exist.

- [ ] **Step 3: Implement local validation and remote pre-mutation checks**

Create `bin/bootstrap-kamal-host` with `set -euo pipefail`. Require
`KAMAL_HOST` and validate `APP_SHARED_ROOT` against:

```bash
^/srv/apps/[^/]+/shared$
```

Normalize `ALLOW_ROOT_DISK_STORAGE` exactly as preflight does, then SSH as
root with only the shared root and normalized flag. In the remote script:

```bash
fail() {
  echo "error=$1" >&2
  exit 1
}

app_shared_root="$1"
allow_root_disk_storage="$2"
app_root=${app_shared_root%/shared}
app_name=${app_root##*/}
backup_root="/srv/backups/$app_name"
```

Before any mutation:

1. Compare `findmnt` sources and require the exact opt-in for a shared source.
   When the exact opt-in accepts that source, emit:

   ```text
   warning=root_disk_storage_enabled data_will_not_survive_server_loss
   ```

2. Source `/etc/os-release`; require `ID=ubuntu` and `VERSION_ID=22.04`.
3. Require `apt-get` and `systemctl`.
4. For every managed directory, reject symlinks and existing non-directories.
5. Reject an existing marker if it is a symlink or not a regular file.

Use stable error names:

```text
srv_not_separate_filesystem
unsupported_host_os
host_command_missing
managed_path_invalid
layout_marker_invalid
```

- [ ] **Step 4: Implement Docker and layout mutation**

If `command -v docker` fails, run:

```bash
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io
```

Then always run:

```bash
systemctl enable --now docker
docker info >/dev/null
```

Create or repair paths using `install -d`, followed by explicit `chown` and
`chmod`, matching the spec:

```text
/srv/bootstrap                    0755 root:root
/srv/apps                         0755 root:root
/srv/apps/<app>                   0750 1000:1000
/srv/apps/<app>/shared            0750 1000:1000
/srv/apps/<app>/shared/db         0750 1000:1000
/srv/backups                      0755 root:root
/srv/backups/<app>                0750 root:root
```

Only after Docker, ownership, and mode verification succeed, publish the ready
marker through a fully prepared temporary regular file:

```bash
layout_marker=/srv/bootstrap/.layout-ready
layout_marker_tmp="/srv/bootstrap/.layout-ready.tmp.$$"
install -m 0644 -o root -g root /dev/null "$layout_marker_tmp"
mv -f -- "$layout_marker_tmp" "$layout_marker"
```

The final marker must not exist after a first-run package, Docker, ownership,
mode, or temporary-marker failure. The test harness starts these failure cases
without an existing marker and asserts only a temporary file may remain.

Print:

```text
host_bootstrap=ready
next=bin/setup-kamal
```

Do not delete, move, truncate, or recursively change existing application
contents.

- [ ] **Step 5: Run bootstrap tests and verify they pass**

Run:

```bash
bash -n bin/bootstrap-kamal-host \
  test/scripts/bootstrap_kamal_host_test.sh
bash test/scripts/bootstrap_kamal_host_test.sh
```

Expected: exit 0 with every ordering, type, Docker, marker, and idempotence
case passing.

- [ ] **Step 6: Commit**

```bash
git add bin/bootstrap-kamal-host \
  test/scripts/bootstrap_kamal_host_test.sh
git commit -m "feat(deploy): Bootstrap existing Kamal host"
```

### Task 3: Guided Setup Integration

**Files:**
- Modify: `test/scripts/setup_kamal_test.sh`
- Modify: `bin/setup-kamal`

- [ ] **Step 1: Write failing setup-dispatch tests**

Extend the accepted CLI modes to test:

```bash
bin/setup-kamal
bin/setup-kamal --bootstrap-host
bin/setup-kamal --apply
```

Stub `bin/bootstrap-kamal-host` through a test-controlled project fixture or a
`BOOTSTRAP_KAMAL_HOST_COMMAND` override that defaults to the real repository
script. Assert:

- `--bootstrap-host` loads the secure env file and invokes bootstrap once;
- it does not run preflight, Kamal version, setup, or deploy first;
- its success output includes `next=bin/setup-kamal`;
- its failure exit status and safe error are preserved;
- default validation forwards the root-disk flag to preflight through the
  exported environment;
- default validation says `bin/setup-kamal --bootstrap-host` when the layout
  marker is missing;
- `--apply` behavior remains the first deployment;
- incompatible or additional arguments fail before external commands; and
- neither registry nor Rails secret values appear in output or event logs.

- [ ] **Step 2: Run the focused setup test and verify it fails**

Run:

```bash
bash -n bin/setup-kamal test/scripts/setup_kamal_test.sh
bash test/scripts/setup_kamal_test.sh
```

Expected: fail because `--bootstrap-host` is rejected.

- [ ] **Step 3: Implement the setup action**

Change usage to:

```text
usage: bin/setup-kamal [--bootstrap-host|--apply]
```

Parse one of three mutually exclusive modes: `validate`, `bootstrap`, or
`apply`. Keep env-file existence, required secrets, template-host, and mode
checks. For bootstrap mode, delegate before preflight:

```bash
bootstrap_command=${BOOTSTRAP_KAMAL_HOST_COMMAND:-"$HERE/bin/bootstrap-kamal-host"}
exec "$bootstrap_command"
```

For default validation, when preflight returns
`bootstrap_layout_not_ready`, add:

```text
hint=run bin/setup-kamal --bootstrap-host to prepare this existing host
```

Do not automatically mutate the host from validation or `--apply`.

- [ ] **Step 4: Run focused setup and related wrapper tests**

Run:

```bash
bash -n bin/setup-kamal test/scripts/setup_kamal_test.sh
bash test/scripts/setup_kamal_test.sh
bash test/scripts/pre_deploy_hook_test.sh
bash test/scripts/deploy_staging_wrapper_test.sh
```

Expected: exit 0 for all commands.

- [ ] **Step 5: Commit**

```bash
git add bin/setup-kamal test/scripts/setup_kamal_test.sh
git commit -m "feat(deploy): Guide existing-host bootstrap"
```

### Task 4: Operational Documentation and Full Verification

**Files:**
- Modify: `.env.deploy.example`
- Modify: `.env.deploy.staging.example`
- Modify: `docs/DEPLOY.md`
- Modify: `docs/MIGRATION_FROM_HATCHBOX.md`
- Modify: `config/deploy.yml`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update checked-in environment examples**

Add the safe default to both examples:

```bash
# Keep 0 for a separate durable /srv mount. Set exactly 1 only when accepting
# that app data is stored on, and lost with, the server root disk.
ALLOW_ROOT_DISK_STORAGE=0
```

Do not alter or populate any secret fields. Explain that the live
`.env.deploy` must be edited in place so handoff regeneration does not
overwrite secrets.

- [ ] **Step 2: Update active deployment guidance**

In `docs/DEPLOY.md`:

- retain a distinct `/srv` filesystem as the default;
- document the exact opt-in and warning;
- add `bin/setup-kamal --bootstrap-host` before validation for this existing
  Ubuntu 22.04 host;
- distinguish root-disk persistence across deploy/reboot from loss on server
  deletion/rebuild;
- state that `/srv/backups` on the same disk is not disaster recovery;
- say the dotfiles volume verifier is intentionally not authoritative for this
  exception;
- include `df -h / /srv` in post-deploy verification;
- preserve the manual DNS and foreign-ingress gates.

Align `docs/MIGRATION_FROM_HATCHBOX.md`, `config/deploy.yml`, and `CLAUDE.md`
without rewriting historical superseded specs.

- [ ] **Step 3: Run all shell tests**

Run:

```bash
for test_file in test/scripts/*_test.sh; do
  bash "$test_file"
done
```

Expected: every script exits 0.

- [ ] **Step 4: Run syntax, Rails, and diff verification**

Run:

```bash
bash -n bin/deploy-preflight bin/bootstrap-kamal-host bin/setup-kamal \
  test/scripts/deploy_preflight_test.sh \
  test/scripts/bootstrap_kamal_host_test.sh \
  test/scripts/setup_kamal_test.sh
bin/rails test
git diff --check
git status --short
```

Expected: Bash syntax succeeds; Rails reports 14 runs with 0 failures and 0
errors; diff check succeeds; status contains only the intended files.

- [ ] **Step 5: Review for secret exposure and destructive behavior**

Inspect the complete branch diff:

```bash
git diff main...HEAD
```

Confirm no real deploy values are present, neither remote script receives
`KAMAL_REGISTRY_PASSWORD` nor `RAILS_MASTER_KEY`, and bootstrap contains no
`rm`, recursive `chown`/`chmod`, DNS mutation, firewall mutation, Docker prune,
or application deployment.

- [ ] **Step 6: Commit documentation**

```bash
git add .env.deploy.example .env.deploy.staging.example \
  docs/DEPLOY.md docs/MIGRATION_FROM_HATCHBOX.md \
  config/deploy.yml CLAUDE.md \
  docs/superpowers/plans/2026-07-27-root-disk-kamal.md
git commit -m "docs(deploy): Explain root-disk Kamal operation"
```

- [ ] **Step 7: Request implementation and final reviews**

Use `superpowers-ruby:requesting-code-review` to verify the implementation
against:

```text
docs/superpowers/specs/2026-07-27-root-disk-kamal-design.md
docs/superpowers/plans/2026-07-27-root-disk-kamal.md
```

Address blocking findings with focused tests, then rerun the full verification
before integration.

## Live Host Handoff

Live host mutation is intentionally outside repository implementation. After
the branch is reviewed and integrated:

1. Add `ALLOW_ROOT_DISK_STORAGE=1` to the existing gitignored `.env.deploy`
   without overwriting its other values.
2. Run `bin/setup-kamal --bootstrap-host` with separate approval for the SSH,
   package installation, systemd, and filesystem changes.
3. Rerun `bin/setup-kamal`.
4. Stop and report any foreign ingress, ownership mismatch, unsupported host,
   package failure, or low-disk warning; do not bypass it.
5. Only after DNS resolves to the server, run `bin/setup-kamal --apply` with
   separate approval because it is the first external deployment.
