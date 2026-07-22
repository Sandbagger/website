# Migration from Hatchbox to Kamal

Record of the 2026-04 migration off Hatchbox onto Kamal v2. Companion to
`docs/DEPLOY.md` — that one is operational ("how do I deploy"), this one is
"why things look the way they do."

## Why

Removing a vendor. Hatchbox was doing three things: provisioning the VPS,
deploying on push, and managing env vars/SSL. Kamal + a self-managed Hetzner
host covers all three with less abstraction between us and the running
container, and nothing to renew or pay for beyond the VPS itself.

## Decisions

### Target host: shared Hetzner box, not a fresh VPS

The dotfiles repo already provisions a shared Hetzner host via OpenTofu
(`docs/HETZNER_KAMAL_SHARED_HOST.md`) intended to host multiple small apps on
one machine. This site is small enough that it belongs there, not on its own
VPS. Per-app isolation is provided by the `/srv/apps/<app>/shared` contract.

### Registry: GHCR

- Free for private + public repos.
- Lives under the same GitHub org (`Sandbagger`) as the source; auth via a
  PAT with `write:packages`.
- Docker Hub has free-tier pull rate limits that can bite in production.
- Hetzner's own registry is still immature.

### Two Kamal roles on one image (`web` + `litestream`)

Litestream was in the Procfile under Hatchbox (`bin/rails litestream:replicate`).
Kept under Kamal as its own role rather than:

- **Accessory** — would need its own image and its own config, and the current
  setup uses the Ruby gem's rake task, not the standalone binary.
- **Co-process in `web` container via foreman** — foreman-in-container has
  signal-handling sharp edges and fights Kamal's "one process per container"
  model.

Two roles on the same image share `/rails/storage` via the volume mount; the
web container writes SQLite (WAL mode, one writer), litestream reads. Cost is
running one extra small container.

### Keep Litestream (belt + suspenders) despite host-level backups

The shared-host contract already provisions `/srv/backups/website` snapshots.
Litestream gives point-in-time continuous replication on top of that. At the
scale of a personal blog, the marginal cost is trivial and the failure modes
are genuinely different (host-level snapshots won't help if the VPS
catastrophically loses its volume between snapshot runs).

### `config.assume_ssl = true` in production

kamal-proxy terminates TLS upstream and talks to the container in plain HTTP.
Without `assume_ssl`, `config.force_ssl = true` (already set) would see the
incoming request as HTTP and redirect to HTTPS → proxy forwards to container
as HTTP → redirect loop. Turning on `assume_ssl` tells Rails to trust
`X-Forwarded-Proto` from the upstream proxy. Safe under Hatchbox too (it also
terminates TLS upstream), so this is a no-op during the overlap window.

### SQLite compile flags live in two places

`README.md` documents the `bundle config set build .sqlite3 …` string for
local development. The `Dockerfile` applies the same string before
`bundle install` in the build stage. These must be kept in sync — if you
change one, change the other. Cross-referenced from `CLAUDE.md` so future me
doesn't miss it.

### Database path: `storage/db/production.sqlite3`, no `DATABASE_URL` override

The scaffold template set `DATABASE_URL=sqlite3:///rails/storage/db/production.sqlite3`
which conflicted with `config/database.yml`'s relative `storage/db/production.sqlite3`
path. Dropped the `DATABASE_URL` override; `database.yml` resolves to
`/rails/storage/db/production.sqlite3` with `WORKDIR=/rails`. `LITESTREAM_DATABASE_PATH`
is set explicitly to match.

## What changed in the repo

Added:
- `Dockerfile`, `.dockerignore`, `bin/docker-entrypoint`
- `config/deploy.yml` (scaffold placeholders filled in)
- `docs/DEPLOY.md`, `docs/MIGRATION_FROM_HATCHBOX.md` (this file)

Modified:
- `Gemfile` / `Gemfile.lock` — `kamal ~> 2.0` in `:development`, `require: false`.
- `bin/deploy` — shells out via `bundle exec kamal`.
- `config/environments/production.rb` — `config.assume_ssl = true`.
- `.gitignore` — `.env.deploy`.
- `CLAUDE.md` — deploy section, SQLite-flags cross-reference.

Recovered:
- `README.md` — the scaffold overwrote the Lite-Rails README; restored from
  git. The scaffold template has a bug (a deploy scaffold should not clobber
  project docs); flagged upstream in the dotfiles repo.

## Cutover plan

Overlap window, no big-bang cutover:

1. Stand up `bundle exec kamal setup` against the shared host. Verify:
   - `GET /` returns 200 and renders the layout.
   - `GET /feed` returns XML.
   - `GET /writing/<any-post>` renders markdown.
   - Litestream logs show continuous replication to S3/B2.
2. Visit the Kamal host directly via IP (bypassing DNS) to confirm before flip.
3. DNS cutover: `williamneal.dev` → Kamal host IP. TTL should be short
   (≤5 min) before the flip.
4. After 48h clean, stop Hatchbox services; cancel the plan after a further
   week of no incidents.

## Rollback

- DNS flip back to the Hatchbox host — Hatchbox keeps serving during the
  overlap window, so rollback is just a DNS change.
- If the Kamal host's SQLite diverges from Hatchbox's during overlap, accept
  the loss — the site is stateless aside from its content and deployment data.
- Longer-term rollback (>48h) is off the table because Hatchbox gets
  decommissioned. If something breaks after that, it's forward-fix.

## Known follow-ups

- **Create the staging DNS record** — point `staging.williamneal.dev` at the
  shared Kamal host before running `bin/deploy staging setup`.
- **Validate the Docker build locally** before first `kamal setup` — requires
  Docker Desktop running. Catches SQLite compile / asset precompile failures
  without a round-trip to the registry.
- **Confirm GHCR auth credential** — PAT under `Sandbagger` org or personal
  handle? Both work with GHCR; pick one and note it in 1Password.
- **Remove `Procfile`'s `litestream:` line** once Kamal is the only deploy
  path. Under Kamal, Litestream runs as its own role; the Procfile line is
  only used on Hatchbox.
- **Delete `.kamal/` dir** — empty leftover from an earlier scaffold attempt;
  Kamal v2 doesn't use it.
