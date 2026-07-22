# Guarded migration from Hatchbox to Kamal

This is the rationale and guarded cutover record for a planned move from
Hatchbox to Kamal v2. It does not claim that the migration is complete.
`docs/DEPLOY.md` is the operator runbook.

## Why

Removing a vendor. Hatchbox currently provisions the VPS, deploys on push, and
manages env vars/SSL. Kamal + a self-managed Hetzner host covers those concerns
with less abstraction between us and the running container.

## Decisions

### Target host: shared Hetzner box, not a fresh VPS

The dotfiles repo provisions a shared Hetzner host via OpenTofu
(`docs/HETZNER_KAMAL_SHARED_HOST.md`) intended to host multiple small apps on
one machine. This site is small enough that it belongs there, not on its own
VPS. Per-app isolation is provided by the `/srv/apps/<app>/shared` contract.

### Registry: GHCR

- Free for private + public repos.
- Lives under the same GitHub org (`Sandbagger`) as the source; auth via a PAT
  with `write:packages`.
- Docker Hub has free-tier pull rate limits that can bite in production.
- Hetzner's own registry is still immature.

### Two Kamal roles on one image (`web` + `litestream`)

Litestream is in the Procfile under Hatchbox (`bin/rails litestream:replicate`).
It remains a separate Kamal role rather than:

- **Accessory** — would need its own image and its own config, and the current
  setup uses the Ruby gem's rake task, not the standalone binary.
- **Co-process in `web` container via foreman** — foreman-in-container has
  signal-handling sharp edges and fights Kamal's "one process per container"
  model.

Two roles on the same image share `/rails/storage` via the volume mount; the
web container writes SQLite (WAL mode, one writer), Litestream reads. Cost is
running one extra small container.

### Keep Litestream (belt + suspenders) despite host-level backups

The shared-host contract provisions `/srv/backups/website` snapshots.
Litestream gives point-in-time continuous replication on top of that. At the
scale of a personal blog, the marginal cost is trivial and the failure modes
are genuinely different: host-level snapshots do not cover every volume-loss
window between snapshot runs.

### `config.assume_ssl = true` in production

kamal-proxy terminates TLS upstream and talks to the container in plain HTTP.
Without `assume_ssl`, `config.force_ssl = true` would redirect the forwarded
HTTP request back to HTTPS in a loop. `assume_ssl` makes Rails trust
`X-Forwarded-Proto` from the upstream proxy. It is safe under Hatchbox too, so
it does not force the cutover.

### SQLite compile flags live in two places

`README.md` documents the `bundle config set build .sqlite3 …` string for
local development. The `Dockerfile` applies the same string before
`bundle install` in the build stage. Keep them in sync.

### Database path: `storage/db/production.sqlite3`, no `DATABASE_URL` override

The scaffold's `DATABASE_URL=sqlite3:///rails/storage/db/production.sqlite3`
conflicted with `config/database.yml`'s relative
`storage/db/production.sqlite3` path. Without that override, `database.yml`
resolves to `/rails/storage/db/production.sqlite3` with `WORKDIR=/rails`.
`LITESTREAM_DATABASE_PATH` is set explicitly to match.

## Guarded cutover and rollback

Follow the guarded checklist in `docs/DEPLOY.md`: locally build and render
without secret output; validate staging TLS `/up`, pages/feed, and an isolated
remote replica restore; then independently verify the public firewall TCP
80/443 path and ingress before production DNS changes. Provider firewall,
DNS, Let's Encrypt, and volume state are live external state, so treat local
success as insufficient.

Lower the TTL and wait the original TTL, announce maintenance, point DNS to
the Kamal host, and run setup. Do not visit the target IP directly before DNS:
automatic TLS requires hostname DNS. Accept the deployment only after TLS,
health, WAL/readiness, and remote replica restore verification succeed.

If setup, TLS, health, or replica verification fails, return DNS to Hatchbox.
Do not take over a foreign listener on 80/443 and do not overwrite persistent
data while diagnosing the failure.

Hatchbox's Procfile/service remains during the observation period. It may be
removed only in a separate later decommission change, after the guarded
cutover has been accepted and observed.

## Data policy during overlap

The deployment design does not silently reconcile independent SQLite writers.
Write-backed features require a freeze during the cutover window, or a
separately approved data migration/restore design before the DNS change. Do
not accept data loss as an implicit rollback strategy.

## Known follow-ups

- Create the staging DNS record before running `bin/deploy staging setup`; the
  hostname must resolve for automatic TLS.
- Validate the local Docker build before the first setup to catch SQLite
  compile and asset-precompile failures without a registry round-trip.
- Confirm the GHCR credential source in 1Password without recording the
  credential in the repository.
- Decommission Hatchbox and remove its Procfile/service only in the later,
  explicitly scoped decommission change.
