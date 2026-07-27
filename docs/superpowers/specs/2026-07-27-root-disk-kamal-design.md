# Root-Disk Kamal Host Design

## Status

Approved design for the initial `williamneal.dev` Kamal deployment. This
document amends the storage requirement in the current deployment
documentation: a distinct `/srv` filesystem remains the safe default, but this
specific existing Hetzner server may use `/srv` on its root disk after an
explicit opt-in.

The server has one approximately 19 GB root disk, 2 GB of RAM, and no attached
Hetzner volume. The site starts with a fresh SQLite database, sends no email,
and is currently populated from Markdown. The operator accepts that deleting
or rebuilding the server will also delete the database and uploaded files.

## Goal

Deploy the website with Kamal to the existing Hetzner server without buying a
separate volume, while preventing an accidental weakening of the durable
storage check for any other deployment.

## Safety Boundary

`bin/deploy-preflight` continues to require `/srv` to be on a filesystem
different from `/` by default. Root-disk storage is accepted only when the
loaded deploy environment contains the exact value:

```bash
ALLOW_ROOT_DISK_STORAGE=1
```

An unset, blank, or differently valued variable does not opt in. The variable
is passed to the remote preflight as a positional argument; the deploy
environment and its secrets are never copied to the server or printed.

The opt-in changes only the filesystem-source invariant. It does not bypass:

- the `/srv/bootstrap/.layout-ready` marker;
- the fixed `/srv/apps/<service>/shared` path;
- root ownership of `/srv/apps`;
- UID/GID `1000:1000` ownership of the app shared directory and its `db`
  directory;
- rejection of symlinked app storage;
- Docker availability; or
- ingress inspection and rejection of any process or container other than the
  exact `kamal-proxy` owner of ports 80 and 443.

When root-disk storage is accepted, preflight emits a non-secret warning that
application state is on the server root disk and will not survive server
deletion or rebuild. Preflight remains noninteractive and fails closed.

## Existing-Host Bootstrap

The setup helper gains the explicit action
`bin/setup-kamal --bootstrap-host`. Its normal mode remains read-only
validation, and `--apply` remains the first Kamal deployment. Unexpected
arguments remain errors. The bootstrap action:

1. Connects to the configured existing host as root.
2. Applies the same separate-filesystem check and exact root-disk opt-in as
   deployment preflight.
3. Verifies `/etc/os-release` identifies Ubuntu 22.04 and that `apt-get` and
   `systemctl` are available. Other operating systems fail before mutation.
4. Refuses unexpected storage objects such as symlinks at the managed paths.
5. If the `docker` command is absent, runs `apt-get update` followed by a
   noninteractive `apt-get install -y docker.io`; otherwise it does not invoke
   the package manager. It then runs `systemctl enable --now docker` and
   verifies `docker info`.
6. Creates `/srv/bootstrap`, `/srv/apps`,
   `/srv/apps/website/shared/db`, and `/srv/backups/website`.
7. Keeps `/srv/apps` root-owned and assigns the application storage tree to
   UID/GID `1000:1000`.
8. Writes `/srv/bootstrap/.layout-ready` only after all preceding checks pass.

The managed layout is exact:

| Path | Type | Mode | Owner |
|---|---|---:|---|
| `/srv/bootstrap` | directory | `0755` | `root:root` |
| `/srv/bootstrap/.layout-ready` | regular file | `0644` | `root:root` |
| `/srv/apps` | directory | `0755` | `root:root` |
| `/srv/apps/website` | directory | `0750` | `1000:1000` |
| `/srv/apps/website/shared` | directory | `0750` | `1000:1000` |
| `/srv/apps/website/shared/db` | directory | `0750` | `1000:1000` |
| `/srv/backups` | directory | `0755` | `root:root` |
| `/srv/backups/website` | directory | `0750` | `root:root` |

Every managed path must either be absent or have the listed type. Symlinks and
non-directory objects are rejected; the marker must be a regular,
non-symlinked file. Existing directory contents are preserved. The action is
idempotent: rerunning it repairs only the listed modes and ownership without
removing application data. It does not partition the root disk, create a loop
device, attach a Hetzner volume, change DNS, open the provider firewall,
displace ingress, deploy the application, or create an off-host backup.

The bootstrap action is allowed to initialize root-disk `/srv` only when
`ALLOW_ROOT_DISK_STORAGE=1` is present. Without that opt-in, it requires an
already mounted separate `/srv` filesystem and fails before installing or
changing anything. This ordering prevents a mistaken command from converting
the default durable-volume design into root-disk storage.

## Operator Flow

The checked-in deploy environment examples document the variable with the
safe default disabled. For this server, the operator adds
`ALLOW_ROOT_DISK_STORAGE=1` to the existing gitignored `.env.deploy` without
regenerating or overwriting its secrets.

The guided sequence is:

1. Run the setup helper in validation mode.
2. If the host layout is absent, run
   `bin/setup-kamal --bootstrap-host`.
3. Rerun validation and resolve any firewall or foreign-ingress failure.
4. Point `williamneal.dev` DNS at the existing server and verify public
   resolution.
5. Run `bin/setup-kamal --apply` for the first deployment.
6. Verify TLS, `/up`, public pages, the feed, and available disk space.
7. Use `bin/deploy` for subsequent releases.

The helper tells the operator the next command after a successful bootstrap
or validation. It does not ask for or echo secret values.

The dotfiles `dotfiles-hetzner-tf verify` and `handoff` commands continue to
describe the separate-volume host contract and are not treated as successful
validation for this exception. The website repository's preflight is the
authoritative deployment gate when the explicit root-disk opt-in is enabled.

## Data and Recovery Consequences

`/srv/apps/website/shared` remains mounted into the container at
`/rails/storage`, so SQLite data and uploaded files survive container
replacement, Kamal deployments, Docker restarts, and ordinary server reboots.
They do not survive deletion, rebuild, loss, or corruption of the Hetzner
server's root disk.

`/srv/backups/website` is on that same disk. It may be useful for local
maintenance copies but is not a disaster-recovery backup. This design does
not add Litestream, another Rails replication mechanism, or paid storage.
Before the site holds data that cannot be recreated, add and test an off-host
backup or attach a separate volume.

Because the disk is small, the operator should check free space during initial
verification and periodically thereafter. A full disk can prevent SQLite
writes and Docker image pulls. The bootstrap and deploy tools do not
automatically prune images or application data.

## Error Handling

- Invalid or absent opt-in plus a shared `/` and `/srv` source:
  `error=srv_not_separate_filesystem`.
- Root-disk opt-in during bootstrap without the exact value `1`: fail before
  package installation or filesystem mutation.
- Missing layout, invalid ownership, symlinks, unavailable Docker inspection,
  or foreign ingress: preserve the existing error and abort before Kamal.
- SSH or package installation failure: stop bootstrap without writing the
  layout-ready marker.
- Successful root-disk acceptance: print the risk warning and continue.

No failure path deletes files, clears a directory, overwrites the deploy
environment, modifies DNS, or suppresses an existing ingress conflict.

## Testing

Focused shell tests use stubbed SSH, filesystem, package-manager, Docker, and
systemd commands. They must prove:

- the existing same-filesystem case still fails by default;
- `ALLOW_ROOT_DISK_STORAGE=1` permits that case and emits the warning;
- blank and invalid values fail closed;
- a separate `/srv` filesystem continues to pass without the opt-in;
- the opt-in is forwarded without forwarding secrets;
- bootstrap refuses root-disk storage without the opt-in before mutation;
- bootstrap creates and verifies the expected layout with the opt-in;
- bootstrap is idempotent and does not remove existing files;
- bootstrap does not write the marker after an installation or ownership
  failure;
- guided setup reports the correct next action without revealing secrets; and
- existing ingress and ownership rejection tests continue to pass.

Repository verification includes Bash syntax checks, the focused deployment
script suite, the Rails test suite, and a secret scan of tracked changes. Live
verification on the existing host remains a separately approved external
operation after the local implementation is reviewed.
