# Kamal Hatchbox Cutover Design

## Goal

Make the repository ready to move `williamneal.dev` from Hatchbox to Kamal on
the OpenTofu-managed shared Hetzner host, while retaining Hatchbox only as an
external rollback target during the observation window.

## Architecture

OpenTofu in the dotfiles repository owns the Hetzner host, firewall, Docker
baseline, optional persistent volume, and stable `/srv` layout. The website
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

## Cutover Configuration

- `bin/deploy` loads the untracked production environment file and checks that
  the host and durable-mount contract are present before invoking Kamal.
- `config/deploy.yml` deploys `williamneal.dev` through `kamal-proxy` with
  automatic TLS, ports 80/443, and application port 3000.
- `.kamal/hooks/pre-app-boot` creates the required app-owned storage
  directories on the host with the container UID/GID before Rails prepares
  the database.
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
   volume is enabled.
3. Point `staging.williamneal.dev` at Hetzner and run the staging setup. Verify
   automatic TLS, the Rails health endpoint, public pages, feed, and
   Litestream replication without disturbing production DNS.
4. Lower the TTL for `williamneal.dev`, point it at Hetzner, then run the
   production setup. Kamal can obtain the production Let's Encrypt certificate
   only after that hostname resolves to the Hetzner host. Keep Hatchbox
   running for at least 48 hours; DNS remains the rollback mechanism.
5. Stop and cancel Hatchbox only after the observation window, then remove its
   `Procfile` entry and the now-obsolete rollback documentation.

## Error Handling

The deploy wrapper must fail before a deployment when the production env file,
the host name, or the durable mount path is missing. Kamal must abort on a
failed hook, image build, deployment health check, or TLS setup. No process
may replace or delete the Hatchbox service as part of configuration work.

## Testing

Focused shell tests cover the deploy wrapper and storage hook. Configuration
validation will additionally check the rendered Kamal configuration and
Docker build. Live host and DNS checks remain explicit operator steps because
they are external-state changes.
