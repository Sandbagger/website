# Deploying williamneal.dev

Kamal v2 onto the OpenTofu-managed Hetzner shared host (contract documented in
`docs/HETZNER_KAMAL_SHARED_HOST.md` in the dotfiles repo).

## Files in this repo

- `Dockerfile` — multi-stage build; rebuilds `sqlite3` with the project's compile flags (`DQS=0`, FTS5, etc.).
- `.dockerignore` — keeps dev cruft out of the build context.
- `config/deploy.yml` — two roles on one image: `web` (Rails) and `litestream` (replication sidecar).
- `bin/deploy` — loads `.env.deploy`, asserts the shared-host contract vars, then delegates to `bundle exec kamal`.
- `bin/deploy-preflight` — checks host ownership, durable storage, and ingress safety before Kamal changes it.
- `bin/docker-entrypoint` — prepares SQLite, verifies WAL mode, and publishes web readiness before Rails boots.
- `.env.deploy.example` — template for handoff values.
- `.deploy-scaffold.json` — manifest tracking the upstream `hetzner-basic` template.

## Host invariants

`bin/deploy` runs the preflight immediately before any Kamal action. Do not
work around a failed preflight; repair the underlying host contract and run it
again.

- `/srv/bootstrap/.layout-ready` must exist. It is the OpenTofu bootstrap
  marker for the shared host.
- `/srv` must be a distinct durable `/srv` mount, not the root disk. It is the
  only accepted location for application state.
- Each service uses `/srv/apps/<service>/shared` (for example,
  `/srv/apps/website/shared`). `/srv/apps` is root-owned, while each app root
  and its `db/` directory are materialized as `1000:1000`.
- Ports 80 and 443 must be unbound or owned by the exact `kamal-proxy`
  container. Existing ingress is never displaced to make a deployment work.
- The web role clears `.web-ready`, prepares SQLite, verifies WAL mode, and
  writes the marker only when it is ready. The Litestream role waits for that
  marker. A successful container start is not enough: verify a remote replica
  restore after deployment before accepting the deploy.

The provider firewall, DNS, Let's Encrypt, and volume checks are **live
external state**. They are not established by local rendering or documentation
review, and they must be checked independently during an operator run.

## One-time bootstrap

```bash
# 1. Generate shared-host values.
dotfiles-hetzner-tf handoff website --format env > .env.deploy

# 2. Fill the blank secret slots in .env.deploy from 1Password.
#    Never print the completed file or copy its values into the shell history.

# 3. Run the guarded checklist below before `bin/deploy setup`.
bin/deploy setup
bin/deploy
```

## Staging isolation

Staging is a separate Kamal destination at `staging.williamneal.dev`, with the
separate service `website-staging`. It must never share production's mounted
directory, database, Active Storage files, or Litestream replica path.

```bash
dotfiles-hetzner-tf handoff website-staging --format env > .env.deploy.staging
# Fill only the staging secret slots, including a distinct LITESTREAM_REPLICA_URL.
bin/deploy staging setup
bin/deploy staging
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
   Confirm the expected service, storage path, and readiness settings.
2. **Staging:** after its hostname DNS and TLS are live, verify staging TLS
   `/up`, pages/feed, and a remote replica restore. A restore check means
   restoring the replica into an isolated location and confirming the restored
   SQLite data is usable; do not replace the live database to test it.
3. **Before production DNS:** independently test the public firewall TCP 80/443 path.
   Confirm ingress ownership is unbound or the exact `kamal-proxy` container.
   These are live external state checks.
4. Lower the DNS TTL, then wait the original TTL before changing the record.
   Announce maintenance before the production change.
5. Point DNS at the Kamal host, then run setup so Let's Encrypt can validate
   the hostname and Kamal can configure its proxy.
6. Verify production TLS `/up`, pages/feed, WAL/readiness behavior, and a
   remote replica restore before accepting the deployment.
7. Abort the cutover: return DNS to Hatchbox if setup, TLS, health, or replica
   verification fails. Investigate without attempting to displace ingress or
   overwrite persistent data.

## Useful commands

```bash
bin/deploy                          # kamal deploy
bin/deploy console                  # rails console on the web role
bin/deploy dbconsole                # sqlite console on the web role
bin/deploy logs -r web              # tail web logs
bin/deploy logs -r litestream       # tail litestream logs
```

## Refreshing the scaffold

`.deploy-scaffold.json` records the `hetzner-basic` template name + dotfiles
commit SHA at copy time. Run `dotfiles-deploy-scaffold copy hetzner-basic
--force` to pull upstream changes; review the diff before committing.
