#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)

grep -Fx '  config.require_master_key = ENV["SECRET_KEY_BASE_DUMMY"].blank?' \
  "$project_root/config/environments/production.rb"
grep -F 'SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile' \
  "$project_root/Dockerfile"
