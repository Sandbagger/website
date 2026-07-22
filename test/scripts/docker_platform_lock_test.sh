#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)
platforms=$(sed -n '/^PLATFORMS$/,/^$/p' "$project_root/Gemfile.lock")

grep -Fx '  aarch64-linux' <<<"$platforms"
grep -Fx '  x86_64-linux' <<<"$platforms"
