# Remove Litestream Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all Litestream replication behavior and credentials while retaining the durable SQLite volume on `/srv`.

**Architecture:** Kamal will run one `web` role only. The web entrypoint will continue preparing SQLite and validating WAL, but no longer coordinates with a replication sidecar. The runbook will explicitly state that recovery is limited to host-level backups/snapshots.

**Tech Stack:** Rails 8, SQLite, Kamal, Bash, Minitest

---

### Task 1: Remove runtime replication dependencies

**Files:**
- Modify: `Gemfile`, `config/deploy.yml`, `bin/docker-entrypoint`, `Procfile`
- Delete: `bin/litestream-entrypoint`, `bin/verify-litestream-replica`, `config/litestream.yml`, `config/initializers/litestream.rb`, `.kamal/hooks/post-deploy`
- Test: `test/scripts/litestream_removal_test.sh`

- [x] Write an absence test for the Litestream role, environment variables, and files; run it and confirm it fails.
- [x] Remove the gem, role, commands, readiness marker, post-deploy verification, and replica configuration.
- [x] Run the absence test and the relevant deployment scripts.

### Task 2: Align deployment documentation and templates

**Files:**
- Modify: `.env.deploy.example`, `.env.deploy.staging.example`, `docs/DEPLOY.md`, `docs/MIGRATION_FROM_HATCHBOX.md`, `CLAUDE.md`, `README.md`

- [x] Remove Litestream credential instructions and role commands.
- [x] State that SQLite durability is local to `/srv` and recovery depends on separately managed host backups/snapshots.
- [x] Verify no active code or operational documentation refers to Litestream.

### Task 3: Verify and commit

**Files:**
- Delete: `test/scripts/deployment_readiness_test.sh`, `test/scripts/verify_litestream_replica_test.sh`
- Modify: any test that asserts Litestream-specific behavior

- [x] Run the full script suite, Rails tests, dependency check, Docker build, and `git diff --check`.
- [x] Confirm the built image contains no Litestream executable or configuration.
- [x] Commit the removal with a conventional message.
