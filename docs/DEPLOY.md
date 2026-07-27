# Deploying williamneal.dev

Kamal v2 onto an existing Hetzner host. This deployment adapts the shared-host
contract documented in `docs/HETZNER_KAMAL_SHARED_HOST.md` in the dotfiles
repo, with the explicit root-disk exception documented here. The existing
server is being reused; it is not provisioned by the current OpenTofu state.

## Files in this repo

- `Dockerfile` — multi-stage build; rebuilds `sqlite3` with the project's compile flags (`DQS=0`, FTS5, etc.).
- `.dockerignore` — keeps dev cruft out of the build context.
- `config/deploy.yml` — the `web` Rails role and its durable host volume.
- `bin/deploy` — loads `.env.deploy`, asserts the shared-host contract vars, then delegates to `bundle exec kamal`.
- `bin/deploy-preflight` — checks host ownership, durable storage, and ingress safety before Kamal changes it.
- `bin/setup-kamal` — guided helper whose default mode performs read-only validation; `--bootstrap-host` explicitly prepares an existing host, and `--apply` delegates to `bin/deploy setup` (`kamal setup`) for the initial application deployment.
- `bin/bootstrap-kamal-host` — the mutating, idempotent Ubuntu 22.04 host bootstrap invoked by `bin/setup-kamal --bootstrap-host`.
- `bin/docker-entrypoint` — prepares SQLite and verifies WAL mode before Rails boots.
- `.env.deploy.example` — template for handoff values.
- `.deploy-scaffold.json` — manifest tracking the upstream `hetzner-basic` template.

## Host invariants

`bin/deploy` runs the preflight immediately before any Kamal action. Do not
work around a failed preflight; repair the underlying host contract and run it
again.

The wrapper owns Kamal's destination, config file, and hook execution. Select
staging only with the leading `staging` argument; do not pass Kamal `-d`,
`-c`, or `-H` overrides (or their long forms) through `bin/deploy`. Pass safe
short options separately (for example, `logs -v -r web`); ambiguous bundled
short options fail closed.

- `/srv/bootstrap/.layout-ready` must exist. It is the readiness marker written
  by the OpenTofu host bootstrap or the explicit existing-host bootstrap.
- `/srv` should be a distinct durable filesystem. This remains the safe
  default; keep `ALLOW_ROOT_DISK_STORAGE=0` (or leave it unset).
- Root-disk `/srv` is accepted only when the live deploy environment contains
  the exact opt-in `ALLOW_ROOT_DISK_STORAGE=1`. Preflight then emits
  `warning=root_disk_storage_enabled data_will_not_survive_server_loss`.
  Any other value is treated as `0`, so a root-disk host fails closed.
- Each service uses `/srv/apps/<service>/shared`. The deploy wrapper enforces
  the exact production path `/srv/apps/website/shared` and staging path
  `/srv/apps/website-staging/shared` before preflight. `/srv/apps` is
  root-owned; the pre-app-boot hook safely creates or repairs each app root,
  `shared/`, and `shared/db/` as `0750` and `1000:1000` without following
  symlinks.
- Ports 80 and 443 must be unbound or owned by the exact `kamal-proxy`
  container. Existing ingress is never displaced to make a deployment work.
- The web role prepares SQLite and verifies WAL mode before the Rails server
  starts. State on mounted `/srv` survives container replacement, Kamal
  deploys, Docker restarts, and ordinary server reboots. With root-disk
  storage, it is lost when the server/root disk is deleted, rebuilt, lost, or
  corrupted.
- `/srv/backups` is on the same filesystem as the application state. On a
  root-disk host it may hold local maintenance copies, but it is not disaster
  recovery. This repository does not provide off-host backup or replication.

The provider firewall, DNS, Let's Encrypt, and filesystem checks are **live
external state**. They are not established by local rendering or documentation
review, and they must be checked independently during an operator run. The
dotfiles volume verifier describes the default separate-volume contract. It is
intentionally not authoritative when the exact root-disk exception is enabled;
the website repository's preflight is the deployment gate in that case.

## One-time bootstrap

```bash
# 1. Generate shared-host values once.
dotfiles-hetzner-tf handoff website --format env > .env.deploy

# 2. Fill the blank secret slots in .env.deploy from 1Password.
#    Never print the completed file or copy its values into the shell history.

# 3. For this existing Ubuntu 22.04 root-disk host, edit .env.deploy in place:
#    ALLOW_ROOT_DISK_STORAGE=1
#    Do not regenerate the file after adding secrets; handoff output can
#    overwrite the live file and its secret values.

# 4. Explicitly bootstrap the existing host, then validate it.
bin/setup-kamal --bootstrap-host
bin/setup-kamal

# 5. Continue with the guarded cutover operator checklist below.
```

By default, `bin/setup-kamal` is guided validation: it tells the operator
which prerequisite is missing and the exact next action. Its default mode is
read-only: it validates the host contract and Kamal availability without
changing the host or deploying the application.

`bin/setup-kamal --bootstrap-host` is an explicit, mutating SSH operation for
an existing Ubuntu 22.04 host. It is idempotent: it verifies or creates only
the managed `/srv` layout, installs Ubuntu's `docker.io` package only when the
`docker` command is absent, and enables/starts Docker. It does not provision
Hetzner, alter DNS or firewall rules, displace ingress, prune Docker data, or
deploy the application. On success it prints `next=bin/setup-kamal`; rerun the
default validation and resolve any reported ownership or foreign-ingress
failure.

After validation and the separate manual DNS action in checklist step 5,
`bin/setup-kamal --apply` delegates to `bin/deploy setup` (`kamal setup`),
which itself performs the initial application deployment. Use `bin/deploy`
for later releases. None of the setup modes asks for or prints secret values.

## Staging isolation

Staging is a separate Kamal destination at `staging.williamneal.dev`, with the
separate service `website-staging`. It must never share production's mounted
directory, database, or Active Storage files.

Complete the one-time host bootstrap above before the first staging setup.
That establishes the host-level `/srv` layout and readiness marker; Kamal's
pre-app-boot hook creates the staging app directory with the required
ownership.

Before staging setup, create its hostname DNS record and verify that it
publicly resolves to the Hetzner host. Once it does, `bin/deploy staging setup`
performs the initial staging deployment.

```bash
# Generate the staging handoff once, before adding any secrets.
dotfiles-hetzner-tf handoff website-staging --format env > .env.deploy.staging
# From this point on, edit the live staging file in place.
# Fill only the staging secret slots.
# On the documented root-disk host, also set:
# ALLOW_ROOT_DISK_STORAGE=1
# Never rerun the redirection above after adding secrets; it overwrites the
# live staging file.
bin/deploy staging setup
bin/deploy staging logs -r web
```

Staging data lives at
`/srv/apps/website-staging/shared/db/production.sqlite3`. Secrets remain in
the gitignored `.env.deploy` and `.env.deploy.staging` files; 1Password is the
source of truth. Do not put secret values in this repository, documentation,
terminal output, or rendered configuration logs.

## Guarded cutover operator checklist

This checklist deliberately distinguishes local checks from actions against
live external state. Keep Hatchbox serving until the observation period is
complete.

1. **Local only:** run a local Docker build and a configuration render with no secret output.
   Never run `kamal config` with a populated `.env.deploy` or `.env.deploy.staging`.
   For a render, source the corresponding blank `.env.deploy*.example`, then invoke
   `bundle exec kamal config` directly:

   ```bash
   # Production: source only the checked-in blank template.
   set -a
   source .env.deploy.example
   set +a
   bundle exec kamal config

   # Staging: source its separate checked-in blank template.
   set -a
   source .env.deploy.staging.example
   set +a
   bundle exec kamal config -d staging
   ```

   Do not use `bin/deploy` for this local render because the wrapper preflights the host.
   Confirm the expected service and storage path.
2. **Staging:** after its hostname DNS and TLS are live, verify staging TLS
   `/up`, pages/feed, and `df -h / /srv`.
3. **Before production DNS:** independently test the public firewall TCP 80/443 path.
   Confirm ingress ownership is unbound or the exact `kamal-proxy` container.
   These are live external state checks.
4. Lower the DNS TTL, then wait the original TTL before changing the record.
   Announce maintenance before the production change.
5. Manually point production DNS at the Kamal host as a separate action, then
   verify the hostname publicly resolves to that Hetzner host. Then run
   `bin/setup-kamal --apply`; it delegates to `bin/deploy setup` (`kamal
   setup`), which lets Let's Encrypt validate the hostname, configures Kamal's
   proxy, and itself performs the initial application deployment.
6. Verify production TLS `/up`, pages/feed, WAL behavior, and
   `df -h / /srv` before accepting the deployment. On a root-disk host, treat
   available space as operationally critical for both SQLite writes and
   Docker image pulls.
7. Abort the cutover: return DNS to Hatchbox if setup, TLS, or health checks
   fail. Investigate without attempting to displace ingress or overwrite
   persistent data.

## Useful commands

```bash
bin/deploy                          # later production releases (kamal deploy)
bin/deploy console                  # rails console on the web role
bin/deploy dbconsole                # sqlite console on the web role
bin/deploy logs -r web              # tail web logs
```

## Refreshing the scaffold

`.deploy-scaffold.json` records the `hetzner-basic` template name + dotfiles
commit SHA at copy time. Run `dotfiles-deploy-scaffold copy hetzner-basic
--force` to pull upstream changes; review the diff before committing.
