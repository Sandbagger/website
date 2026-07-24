# Kamal Hatchbox Cutover Design

> **Status: Superseded on 2026-07-23.** This historical design includes
> Litestream replication, which has been removed. Follow `docs/DEPLOY.md` and
> `docs/superpowers/plans/2026-07-23-remove-litestream.md` for the current
> single-role deployment and host-backup-only recovery posture.

## Goal

Make the repository ready to move `williamneal.dev` from Hatchbox to Kamal on
the OpenTofu-managed shared Hetzner host, while retaining Hatchbox only as an
external rollback target during the observation window.

## Architecture

OpenTofu in the dotfiles repository owns the Hetzner host, firewall, Docker
baseline, persistent volume, and stable `/srv` layout. The website
repository owns its Kamal deployment, including the GHCR image, TLS host,
roles, runtime environment, and app secrets.

The production app mounts `/srv/apps/website/shared` at `/rails/storage`.
Rails and Litestream use the same SQLite database at
`/rails/storage/db/production.sqlite3`; file-backed Active Storage uses the
same durable mount. Kamal runs Rails as the `web` role and Litestream as a
second, non-proxied role from the same image.

No production database records or uploaded files need to move from Hatchbox:
the site currently has no durable application data. The first Kamal boot will
create a fresh SQLite database and storage tree. If that assumption changes
before cutover, stop and add a separate data-migration design rather than
silently risking data loss.

The Hetzner persistent volume is mandatory for production. Before any Kamal
command, the target must have the OpenTofu bootstrap marker and a mounted
`/srv` runtime root backed by that durable filesystem. A directory merely
named `/srv` on the VM root disk is not sufficient. The deploy preflight must
also establish that ports 80 and 443 are exposed by the OpenTofu firewall and
are either unused or already owned by `kamal-proxy`; it must never displace an
unrelated ingress service.

## Cutover Configuration

- `bin/deploy` loads the untracked production environment file and checks that
  the host and durable-mount contract are present before invoking Kamal.
- `config/deploy.yml` deploys `williamneal.dev` through `kamal-proxy` with
  automatic TLS, ports 80/443, and application port 3000.
- `.kamal/hooks/pre-app-boot` creates the required app-owned storage
  directories on the host with the container UID/GID before Rails prepares
  the database.
- A deploy preflight hook validates the OpenTofu mount/marker, durable-storage
  ownership, firewall reachability, and port ownership before Kamal changes
  the proxy or starts containers.
- The web boot command performs `db:prepare`, explicitly validates SQLite's
  WAL mode on the mounted database, and writes a readiness marker only after
  those checks pass. The Litestream role waits for that marker with a bounded
  timeout before it begins replication, preventing a first-boot race. A
  post-deploy verification must confirm a usable remote replica before the
  deployment is accepted.
- Secrets remain outside Git and are loaded at deploy time:
  `KAMAL_REGISTRY_PASSWORD`, `RAILS_MASTER_KEY`, and the `LITESTREAM_*`
  credentials.
- The existing Hatchbox `Procfile` remains during the overlap so the prior
  service continues to be a viable DNS rollback destination. It is removed
  only after the Kamal host has passed the observation window and Hatchbox is
  intentionally shut down.

## Validation and Cutover

1. Validate the Docker build and the rendered Kamal configuration locally,
   without printing secrets.
2. Confirm the OpenTofu host contract: `/srv/bootstrap/.layout-ready`,
   `/srv/apps`, `/srv/backups`, Docker, and the persistent `/srv` mount when a
   volume is enabled. For production, require the persistent volume to be
   enabled and verify `/srv`'s mount source before continuing.
3. Point `staging.williamneal.dev` at Hetzner and run the staging setup. Verify
   automatic TLS, the Rails health endpoint, public pages, feed, and
   Litestream replication without disturbing production DNS.
4. Before production DNS changes, confirm the public firewall path to ports 80
   and 443 and that no unrelated host ingress occupies them. Lower the TTL for
   `williamneal.dev` and wait one prior TTL. Announce a maintenance window,
   point DNS at Hetzner, then run production setup. Kamal can obtain the
   production Let's Encrypt certificate only after that hostname resolves to
   the Hetzner host. If setup or certificate issuance fails, revert DNS to
   Hatchbox immediately and investigate before retrying.
5. Stop and cancel Hatchbox only after the observation window, then remove its
   `Procfile` entry and the now-obsolete rollback documentation.

Because the site has no user-created persistent data, the maintenance window
and DNS propagation do not create a database-divergence risk. If a
write-backed feature is added before cutover, freeze writes for the rollback
window or create a data migration and restore procedure first.

## Error Handling

The deploy wrapper must fail before a deployment when the production env file,
the host name, durable mount, mount marker, expected ownership, or port
invariant is missing. Kamal must abort on a failed hook, image build,
database/WAL bootstrap, Litestream readiness timeout, deployment health check,
replica verification, or TLS setup. No process may replace or delete the
Hatchbox service as part of configuration work.

## Testing

Focused shell tests cover the deploy wrapper, preflight, storage hook, and
database-to-Litestream readiness handshake. Configuration validation will
additionally check the rendered Kamal configuration and Docker build. Live
host, replica-restore, firewall, ingress, and DNS checks remain explicit
operator steps because they are external-state changes.
