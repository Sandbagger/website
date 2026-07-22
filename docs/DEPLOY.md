# Deploying williamneal.dev

Kamal v2 onto the OpenTofu-managed Hetzner shared host (contract documented in
`docs/HETZNER_KAMAL_SHARED_HOST.md` in the dotfiles repo).

## Files in this repo

- `Dockerfile` — multi-stage build; rebuilds `sqlite3` with the project's compile flags (`DQS=0`, FTS5, etc.).
- `.dockerignore` — keeps dev cruft out of the build context.
- `config/deploy.yml` — two roles on one image: `web` (Rails) and `litestream` (replication sidecar).
- `bin/deploy` — loads `.env.deploy`, asserts the shared-host contract vars, then delegates to `bundle exec kamal`.
- `bin/docker-entrypoint` — runs `db:prepare` on the web role before Rails boots.
- `.env.deploy.example` — template for handoff values.
- `.deploy-scaffold.json` — manifest tracking the upstream `hetzner-basic` template.

## Shared-host contract

- Durable state: `/srv/apps/website/shared` on the host → `/rails/storage` in the container.
- SQLite DB: `/rails/storage/production.sqlite3` (matches `config/database.yml`).
- Active Storage: `/rails/storage`.
- Backups: `/srv/backups/website` — host-level concern, not Kamal's.
- Litestream runs as its own role on the same image, writing to S3/B2 continuously.

## One-time bootstrap

```bash
# 1. Generate handoff values from the live server
hetzner-tf-existing-server-handoff --format env root@shared-kamal-01 website \
  > .env.deploy

# 2. Fill the secret slots in .env.deploy (from 1Password):
#      KAMAL_REGISTRY_PASSWORD  — GitHub PAT with write:packages
#      RAILS_MASTER_KEY         — matches config/master.key
#      LITESTREAM_REPLICA_URL   — s3://bucket/path
#      LITESTREAM_ACCESS_KEY_ID
#      LITESTREAM_SECRET_ACCESS_KEY

# 3. First deploy
bundle exec kamal setup     # idempotent; configures proxy + pulls first image
bin/deploy                  # subsequent deploys
```

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

## Secret handling

`.env.deploy` contains production tokens. It is gitignored. Sources of truth
live in 1Password per the dotfiles secret policy.
