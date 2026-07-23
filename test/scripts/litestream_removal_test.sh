#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)

fail() {
  echo "test failure: $*" >&2
  exit 1
}

for removed_path in \
  bin/litestream-entrypoint \
  bin/verify-litestream-replica \
  config/litestream.yml \
  config/initializers/litestream.rb \
  .kamal/hooks/post-deploy; do
  [[ ! -e "$project_root/$removed_path" ]] || fail "expected $removed_path to be removed"
done

if grep -Fq '.web-ready' "$project_root/.kamal/hooks/pre-app-boot"; then
  fail "expected pre-app-boot to contain no replication readiness marker"
fi

for active_file in \
  Gemfile \
  Gemfile.lock \
  Procfile \
  config/deploy.yml \
  .dockerignore \
  bin/docker-entrypoint \
  .kamal/hooks/pre-app-boot \
  .env.deploy.example \
  .env.deploy.staging.example \
  docs/DEPLOY.md \
  docs/MIGRATION_FROM_HATCHBOX.md \
  CLAUDE.md \
  README.md; do
  if grep -Eiq 'litestream|LITESTREAM' "$project_root/$active_file"; then
    fail "expected $active_file to contain no Litestream configuration"
  fi
done

grep -Fq 'Status: Superseded on 2026-07-23.' \
  "$project_root/docs/superpowers/specs/2026-07-22-kamal-hatchbox-cutover-design.md"
