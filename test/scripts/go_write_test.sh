#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/../.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

make_project() {
  local project_dir=$1

  mkdir -p "$project_dir/app/content/templates" "$project_dir/lib/writing"
  cp "$project_root/go" "$project_dir/go"
  cp "$project_root/app/content/templates/writing.makerb" \
    "$project_dir/app/content/templates/writing.makerb"
  cp "$project_root/lib/writing/path.rb" "$project_dir/lib/writing/path.rb"
  chmod +x "$project_dir/go"
}

run_write() {
  local project_dir=$1 title=$2 topics=$3 output=$4

  (
    cd "$project_dir"
    printf '%s\n%s\n' "$title" "$topics" | ./go write
  ) > "$output" 2>&1
}

run_write_without_topics() {
  local project_dir=$1 title=$2 output=$3

  (
    cd "$project_dir"
    printf '%s\n' "$title" | ./go write
  ) > "$output" 2>&1
}

assert_yaml_title() {
  local draft_path=$1 expected_title=$2

  ruby -ryaml -e \
    'abort unless YAML.safe_load(File.read(ARGV[0])).fetch("title") == ARGV[1]' \
    "$draft_path" "$expected_title"
}

assert_yaml_topics() {
  local draft_path=$1
  shift

  ruby -ryaml -e '
    actual = YAML.safe_load(File.read(ARGV.shift)).fetch("topic")
    abort "topics mismatch: #{actual.inspect}" unless actual == ARGV
  ' "$draft_path" "$@"
}

assert_no_success() {
  local output=$1

  if grep -Fq 'Draft created at ' "$output"; then
    echo "unexpected success message in $output" >&2
    exit 1
  fi
}

assert_no_partial_draft() {
  local drafts_dir=$1

  if [[ -d "$drafts_dir" ]] &&
    find "$drafts_dir" -type f -name '.*.tmp.*' -print -quit | grep -q .; then
    echo "partial draft left in $drafts_dir" >&2
    exit 1
  fi
}

published_project="$temp_dir/published"
make_project "$published_project"
published_posts_dir="$published_project/app/content/pages/writing/posts"
mkdir -p "$published_posts_dir"
published_post="$published_posts_dir/2024-03-10-my-new-post.markerb"
printf '%s\n' 'published post sentinel' > "$published_post"
published_checksum_before=$(cksum < "$published_post")
if run_write "$published_project" 'My New Post' 'Ruby' \
  "$published_project/write.out"; then
  echo 'expected a published slug to block draft creation' >&2
  exit 1
fi
published_checksum_after=$(cksum < "$published_post")
test "$published_checksum_after" = "$published_checksum_before"
grep -Fx \
  'Writing slug already published at app/content/pages/writing/posts/2024-03-10-my-new-post.markerb' \
  "$published_project/write.out"
test ! -e \
  "$published_project/app/content/pages/writing/drafts/my-new-post.markerb"
assert_no_success "$published_project/write.out"
assert_no_partial_draft "$published_project/app/content/pages/writing/drafts"

invalid_post_project="$temp_dir/invalid-post"
make_project "$invalid_post_project"
invalid_posts_dir="$invalid_post_project/app/content/pages/writing/posts"
mkdir -p "$invalid_posts_dir"
printf '%s\n' 'invalid post sentinel' > "$invalid_posts_dir/not-dated.markerb"
if run_write "$invalid_post_project" 'New Draft' 'Ruby' \
  "$invalid_post_project/write.out"; then
  echo 'expected an invalid post filename to block draft creation' >&2
  exit 1
fi
grep -F 'app/content/pages/writing/posts/not-dated.markerb' \
  "$invalid_post_project/write.out"
grep -F 'is missing a publication date' "$invalid_post_project/write.out"
test ! -e \
  "$invalid_post_project/app/content/pages/writing/drafts/new-draft.markerb"
assert_no_success "$invalid_post_project/write.out"
assert_no_partial_draft \
  "$invalid_post_project/app/content/pages/writing/drafts"

basic_project="$temp_dir/basic"
make_project "$basic_project"
run_write "$basic_project" 'My New Post' \
  ' Ruby on Rails , Sitepress ' "$basic_project/write.out"

draft_path="$basic_project/app/content/pages/writing/drafts/my-new-post.markerb"
test -f "$draft_path"
assert_yaml_title "$draft_path" 'My New Post'
assert_yaml_topics "$draft_path" 'Ruby on Rails' 'Sitepress'
ruby -e '
  modes = ARGV.map { File.stat(_1).mode & 0777 }
  abort "mode mismatch: template=%04o draft=%04o" % modes unless modes.uniq.one?
' \
  "$basic_project/app/content/templates/writing.makerb" "$draft_path"
grep -Fx 'Draft created at app/content/pages/writing/drafts/my-new-post.markerb' \
  "$basic_project/write.out"
test ! -e "$basic_project/app/content/pages/writing/drafts/my-new-post.makerb"
test ! -e "$basic_project/app/content/pages/writing/my-new-post.markerb"
test ! -d "$basic_project/app/content/pages/writing/posts"

printf '\nsentinel content\n' >> "$draft_path"
checksum_before=$(cksum < "$draft_path")
if run_write "$basic_project" 'My New Post' 'Ruby' \
  "$basic_project/duplicate.out"; then
  echo 'expected existing draft to be refused' >&2
  exit 1
fi
checksum_after=$(cksum < "$draft_path")
test "$checksum_after" = "$checksum_before"
grep -Fx 'Draft already exists at app/content/pages/writing/drafts/my-new-post.markerb' \
  "$basic_project/duplicate.out"
assert_no_success "$basic_project/duplicate.out"

safe_project="$temp_dir/safe-input"
make_project "$safe_project"
path_title='../../Escaped/Post'
run_write "$safe_project" "$path_title" 'Ruby' "$safe_project/path.out"
safe_draft="$safe_project/app/content/pages/writing/drafts/escaped-post.markerb"
test -f "$safe_draft"
assert_yaml_title "$safe_draft" "$path_title"
test ! -e "$safe_project/Escaped"

quoted_title='  A & B: "quoted" \ slash  '
run_write "$safe_project" "$quoted_title" 'Ruby' "$safe_project/quoted.out"
quoted_draft="$safe_project/app/content/pages/writing/drafts/a-b-quoted-slash.markerb"
test -f "$quoted_draft"
assert_yaml_title "$quoted_draft" "$quoted_title"

unicode_title='Café — Déjà'
run_write "$safe_project" "$unicode_title" 'Ruby' "$safe_project/unicode.out"
unicode_draft="$safe_project/app/content/pages/writing/drafts/caf-d-j.markerb"
test -f "$unicode_draft"
assert_yaml_title "$unicode_draft" "$unicode_title"

for invalid_title in '' '...///!!!'; do
  invalid_output="$safe_project/invalid-${#invalid_title}.out"
  if run_write "$safe_project" "$invalid_title" 'Ruby' "$invalid_output"; then
    echo "expected title without ASCII alphanumerics to be refused" >&2
    exit 1
  fi
  grep -Fx 'Title must contain at least one ASCII letter or number' \
    "$invalid_output"
  assert_no_success "$invalid_output"
done


yaml_project="$temp_dir/yaml-topics"
make_project "$yaml_project"
yaml_topics=' true , null , 123 , A: B , hash # label , [brackets] , "quotes" , back\slash '
run_write "$yaml_project" 'YAML Topics' "$yaml_topics" \
  "$yaml_project/write.out"
yaml_draft="$yaml_project/app/content/pages/writing/drafts/yaml-topics.markerb"
assert_yaml_topics "$yaml_draft" \
  'true' 'null' '123' 'A: B' 'hash # label' '[brackets]' '"quotes"' 'back\slash'

for invalid_topics in '' '   ' ',Ruby' 'Ruby,,Rails' 'Ruby,' 'Ruby,   ' \
  'Ruby, ruby'; do
  invalid_topic_project="$temp_dir/invalid-topic-${#invalid_topics}"
  make_project "$invalid_topic_project"
  invalid_topic_output="$invalid_topic_project/write.out"
  if run_write "$invalid_topic_project" 'Invalid Topics' "$invalid_topics" \
    "$invalid_topic_output"; then
    echo "expected invalid topics to be refused: $invalid_topics" >&2
    exit 1
  fi
  grep -Fx \
    'Topics must be a non-empty comma-separated list without blank or duplicate labels' \
    "$invalid_topic_output"
  test ! -e \
    "$invalid_topic_project/app/content/pages/writing/drafts/invalid-topics.markerb"
  test ! -d "$invalid_topic_project/app/content/pages/writing/drafts"
  assert_no_success "$invalid_topic_output"
  assert_no_partial_draft \
    "$invalid_topic_project/app/content/pages/writing/drafts"
done

eof_project="$temp_dir/topic-eof"
make_project "$eof_project"
if run_write_without_topics "$eof_project" 'Topic EOF' \
  "$eof_project/write.out"; then
  echo 'expected topic EOF to be refused' >&2
  exit 1
fi
grep -Fx 'Failed to read topics' "$eof_project/write.out"
test ! -e "$eof_project/app/content/pages/writing/drafts/topic-eof.markerb"
test ! -d "$eof_project/app/content/pages/writing/drafts"
assert_no_success "$eof_project/write.out"
assert_no_partial_draft "$eof_project/app/content/pages/writing/drafts"

dangling_project="$temp_dir/dangling"
make_project "$dangling_project"
dangling_drafts="$dangling_project/app/content/pages/writing/drafts"
mkdir -p "$dangling_drafts"
dangling_path="$dangling_drafts/dangling.markerb"
ln -s "$dangling_project/missing-target" "$dangling_path"
dangling_target=$(readlink "$dangling_path")
if run_write "$dangling_project" 'Dangling' 'Ruby' \
  "$dangling_project/write.out"; then
  echo 'expected dangling symlink destination to be refused' >&2
  exit 1
fi
test -L "$dangling_path"
test "$(readlink "$dangling_path")" = "$dangling_target"
grep -Fx 'Draft already exists at app/content/pages/writing/drafts/dangling.markerb' \
  "$dangling_project/write.out"
assert_no_partial_draft "$dangling_drafts"

missing_project="$temp_dir/missing-template"
make_project "$missing_project"
rm "$missing_project/app/content/templates/writing.makerb"
if run_write "$missing_project" 'Missing Template' 'Ruby' \
  "$missing_project/write.out"; then
  echo 'expected missing template to fail' >&2
  exit 1
fi
grep -Fx 'Writing template not found at app/content/templates/writing.makerb' \
  "$missing_project/write.out"
assert_no_success "$missing_project/write.out"
assert_no_partial_draft "$missing_project/app/content/pages/writing/drafts"

copy_project="$temp_dir/copy-failure"
make_project "$copy_project"
mkdir "$copy_project/bin"
cat > "$copy_project/bin/cp" <<'SH'
#!/usr/bin/env bash
exit 73
SH
chmod +x "$copy_project/bin/cp"
if PATH="$copy_project/bin:$PATH" \
  run_write "$copy_project" 'Copy Failure' 'Ruby' \
    "$copy_project/write.out"; then
  echo 'expected template copy failure to fail' >&2
  exit 1
fi
grep -Fx 'Failed to copy writing template' "$copy_project/write.out"
test ! -e "$copy_project/app/content/pages/writing/drafts/copy-failure.markerb"
assert_no_success "$copy_project/write.out"
assert_no_partial_draft "$copy_project/app/content/pages/writing/drafts"

substitution_project="$temp_dir/substitution-failure"
make_project "$substitution_project"
cat > "$substitution_project/app/content/templates/writing.makerb" <<'TEMPLATE'
---
topic:
---
TEMPLATE
if run_write "$substitution_project" 'No Title Field' 'Ruby' \
  "$substitution_project/write.out"; then
  echo 'expected missing title field to fail' >&2
  exit 1
fi
grep -Fx 'Failed to populate title in draft' "$substitution_project/write.out"
test ! -e \
  "$substitution_project/app/content/pages/writing/drafts/no-title-field.markerb"
assert_no_success "$substitution_project/write.out"
assert_no_partial_draft \
  "$substitution_project/app/content/pages/writing/drafts"

missing_topic_project="$temp_dir/missing-topic-field"
make_project "$missing_topic_project"
cat > "$missing_topic_project/app/content/templates/writing.makerb" <<'TEMPLATE'
---
title:
---
TEMPLATE
if run_write "$missing_topic_project" 'No Topic Field' 'Ruby, Sitepress' \
  "$missing_topic_project/write.out"; then
  echo 'expected missing topic field to fail' >&2
  exit 1
fi
grep -Fx 'Failed to populate topics in draft' \
  "$missing_topic_project/write.out"
test ! -e \
  "$missing_topic_project/app/content/pages/writing/drafts/no-topic-field.markerb"
assert_no_success "$missing_topic_project/write.out"
assert_no_partial_draft \
  "$missing_topic_project/app/content/pages/writing/drafts"
