#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

mkdir -p "$temp_dir/app/content/templates"
cp "$project_root/go" "$temp_dir/go"
cp "$project_root/app/content/templates/writing.makerb" \
  "$temp_dir/app/content/templates/writing.makerb"
chmod +x "$temp_dir/go"

(
  cd "$temp_dir"
  printf '%s\n' 'My New Post' | ./go write > "$temp_dir/write.out"
)

draft_path="$temp_dir/app/content/pages/writing/drafts/my-new-post.makerb"
test -f "$draft_path"
grep -Fx 'title: My New Post' "$draft_path"
grep -Fx 'Draft created at app/content/pages/writing/drafts/my-new-post.makerb' \
  "$temp_dir/write.out"
test ! -e "$temp_dir/app/content/pages/writing/my-new-post.makerb"
test ! -d "$temp_dir/app/content/pages/writing/posts"

if (
  cd "$temp_dir"
  printf '%s\n' 'My New Post' | ./go write > "$temp_dir/duplicate.out" 2>&1
); then
  echo 'expected existing draft to be refused' >&2
  exit 1
fi

grep -Fx 'Draft already exists at app/content/pages/writing/drafts/my-new-post.makerb' \
  "$temp_dir/duplicate.out"
grep -Fx 'title: My New Post' "$draft_path"
