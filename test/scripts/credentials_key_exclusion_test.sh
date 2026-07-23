#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)

for ignore_file in .gitignore .dockerignore; do
  grep -Fx 'config/master.key' "$project_root/$ignore_file"
  grep -Fx 'config/credentials/*.key' "$project_root/$ignore_file"
done
