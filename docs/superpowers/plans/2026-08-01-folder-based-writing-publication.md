# Folder-Based Writing Publication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace writing front-matter publication flags with visible `drafts/` and dated `posts/` filesystem conventions while preserving stable public URLs and automatic Brussels-midnight publication.

**Architecture:** A pure writing-path value object derives slug and publication date from physical paths. A Sitepress resource pipeline maps dated post files onto stable `/writing/<slug>` nodes and removes drafts from production. A shared catalogue and request-time policy use an injectable Brussels clock, so collections and direct requests agree without rebuilding the Sitepress tree.

**Tech Stack:** Ruby 3.4, Rails 8, Sitepress 4, Phlex, Minitest, Bash

---

## Task 1: Parse Writing Paths and Brussels Publication Dates

**Files:**
- Create: `lib/writing/path.rb`
- Create: `lib/writing/publication_clock.rb`
- Test: `test/lib/writing/path_test.rb`
- Test: `test/lib/writing/publication_clock_test.rb`

- [ ] **Step 1: Write failing path parsing tests**

Cover dated `.markerb`, `.html.markerb`, and `.md` post names, plus draft names. Assert the physical source path, slug, publication date, stable request path, and draft preview path. Assert clear failures for a missing date, impossible date, and missing slug.

```ruby
test "dated post exposes its canonical request path" do
  path = Writing::Path.new(
    "app/content/pages/writing/posts/2024-03-10-example.html.markerb"
  )

  assert_equal Date.new(2024, 3, 10), path.publication_date
  assert_equal "example", path.slug
  assert_equal "/writing/example", path.request_path
end
```

- [ ] **Step 2: Run the focused parser test and confirm it fails**

Run: `bin/rails test test/lib/writing/path_test.rb`

Expected: failure because `Writing::Path` does not exist.

- [ ] **Step 3: Implement the smallest path value object**

Strip the supported Sitepress handler extensions without losing dots inside a slug. Classify only paths directly under `writing/posts/` or `writing/drafts/`. Use `Date.iso8601` for real-calendar validation, expose predicates, and raise `Writing::Path::Invalid` with the source path in every message.

- [ ] **Step 4: Write failing clock tests around Brussels midnight and DST**

Inject UTC instants and assert the local date on both sides of midnight, including summer time (`UTC+02:00`) and winter time (`UTC+01:00`).

```ruby
assert_equal Date.new(2026, 8, 1), clock.today(at: Time.utc(2026, 7, 31, 22, 0))
assert_equal Date.new(2026, 1, 2), clock.today(at: Time.utc(2026, 1, 1, 23, 0))
```

- [ ] **Step 5: Implement and verify the Brussels clock**

Use `ActiveSupport::TimeZone["Europe/Brussels"]` and accept `at:` for deterministic callers.

Run: `bin/rails test test/lib/writing/path_test.rb test/lib/writing/publication_clock_test.rb`

Expected: all focused tests pass.

- [ ] **Step 6: Commit the parsing foundation**

```bash
git add lib/writing test/lib/writing
git commit -m "feat(writing): derive publication state from paths"
```

## Task 2: Validate and Map Sitepress Writing Resources

**Files:**
- Create: `lib/writing/resource_pipeline.rb`
- Create: `config/initializers/sitepress_writing.rb`
- Test: `test/lib/writing/resource_pipeline_test.rb`
- Test: `test/integration/writing_resource_mapping_test.rb`

- [ ] **Step 1: Write failing pipeline unit tests**

Build a small in-memory Sitepress site fixture. Assert that:

- `writing/posts/2024-03-10-example.html.markerb` becomes `/writing/example`.
- The resource receives a derived `publish_at` date for existing presentation code.
- `/writing/posts/2024-03-10-example` no longer exists.
- drafts remain at `/writing/drafts/<slug>` outside production.
- drafts are absent from the production tree.
- duplicate canonical slugs raise with both source paths.
- `status`, `published`, or `publish_at` in front matter raises with the source path and key.

- [ ] **Step 2: Run the focused pipeline test and confirm it fails**

Run: `bin/rails test test/lib/writing/resource_pipeline_test.rb`

Expected: failure because the pipeline is absent.

- [ ] **Step 3: Implement resource validation and remapping**

Make the environment an injected constructor argument. Select resources by their physical asset path, parse each with `Writing::Path`, validate legacy keys before adding derived metadata, and assign explicit canonical Sitepress nodes. Keep scheduled resources in every environment; remove only drafts in production. Detect collisions before mutating the tree.

- [ ] **Step 4: Register the pipeline after Sitepress builds its site**

Explicitly require the two `lib/writing` dependencies in the initializer and attach one deterministic `Sitepress.site.manipulate` block. Avoid boot-time filtering by the current date.

- [ ] **Step 5: Add route-level mapping assertions**

Assert the four current stable URL shapes through `Sitepress.site.get`, plus absence of the physical `posts/` URL. Keep this fixture-independent until content moves in Task 5 by creating resources under a temporary content root.

- [ ] **Step 6: Run focused tests and commit**

Run: `bin/rails test test/lib/writing/resource_pipeline_test.rb test/integration/writing_resource_mapping_test.rb`

Expected: all focused tests pass.

```bash
git add lib/writing/resource_pipeline.rb config/initializers/sitepress_writing.rb test/lib/writing/resource_pipeline_test.rb test/integration/writing_resource_mapping_test.rb
git commit -m "feat(writing): map dated posts to stable URLs"
```

## Task 3: Migrate Content and Centralize Publication Behavior Atomically

**Files:**
- Create: `app/models/writing/catalogue.rb`
- Create: `app/models/writing/publication_policy.rb`
- Modify: `app/controllers/sitepress/site_controller.rb`
- Modify: `app/controllers/feed_controller.rb`
- Move/edit: `app/content/pages/writing/*.markerb`
- Move/edit: `app/content/pages/writing/*.html.markerb`
- Create: `app/content/templates/writing.makerb`
- Delete: `app/content/pages/writing/template.makerb`
- Test: `test/models/writing/catalogue_test.rb`
- Test: `test/models/writing/publication_policy_test.rb`
- Test: `test/integration/writing_publication_access_test.rb`
- Test: `test/integration/feed_publication_test.rb`
- Modify: `test/integration/pages_smoke_test.rb`
- Modify: `test/integration/writing_collection_test.rb`

- [ ] **Step 1: Write failing publication policy tests**

In production, assert a dated post is blocked before its publication date and public on and after that date. Assert a future post is previewable in development and test. Assert drafts are never considered published.

- [ ] **Step 2: Write failing catalogue tests**

With published, scheduled, draft, and non-writing resources, assert that `published` returns only due posts, newest first, and can exclude a canonical request path. Inject the current date rather than stubbing global time.

- [ ] **Step 3: Implement policy and catalogue**

Keep both classes small and dependency-injected. The catalogue should inspect the resource's physical asset path through `Writing::Path`, not infer state from its remapped request path. It may read derived `publish_at` only for display compatibility, never as publication authority. Do not switch the real controllers until the content moves later in this same task.

- [ ] **Step 4: Add migration and feed assertions before moving files**

Assert every existing published path still resolves after migration:

```text
/writing/markdown-in-rails-with-phlex-and-sitepress
/writing/tag-overriding-in-phlex-and-markdown
/writing/capture-request-referrer-via-css
/writing/pettis-good-tariffs-vs-bad
```

Assert the four are ordered by filename-derived dates and that no legacy publication keys exist in writing front matter. Add a feed-level test proving the XML includes due posts but excludes drafts and scheduled posts.

- [ ] **Step 5: Move and clean the existing writing resources**

Move the four published resources into `posts/` using these authoritative filenames:

```text
2024-02-27-markdown-in-rails-with-phlex-and-sitepress.html.markerb
2024-03-03-tag-overriding-in-phlex-and-markdown.html.markerb
2024-03-10-capture-request-referrer-via-css.html.markerb
2025-10-12-pettis-good-tariffs-vs-bad.markerb
```

Move `embrace_the_cascade_in_your_rails_app`, `national-accounting`, `tailwind-vs-semantic-css`, and `why-I-made-this-site-with-phlex-sitepress-and-rails` into `drafts/` without adding dates. Move the template to `app/content/templates/writing.makerb`. Delete `status`, `published`, and `publish_at` from every migrated writing resource without changing other metadata or article bodies.

- [ ] **Step 6: Replace duplicated controller queries**

Have the Sitepress page controller and feed controller instantiate the shared catalogue. Preserve current request exclusion in article recommendations. Change `writing_post?` so draft previews use the article layout without classifying the `/writing` archive itself as an article.

- [ ] **Step 7: Add a production direct-request guard**

Before rendering a Sitepress resource, apply the publication policy to post resources in production and raise `Sitepress::ResourceNotFound` for scheduled posts. Do not cache the decision or remove scheduled resources at boot. Let development and test render scheduled previews normally.

- [ ] **Step 8: Update smoke enumeration and prove timed availability without rebuilding**

Ensure the smoke test requests canonical Sitepress paths after the resource pipeline runs. In the access integration test, keep the same Sitepress resource instance, inject a time immediately before Brussels midnight and expect 404, advance past midnight, request again, and expect success. Also assert `/writing/posts/<dated-name>` is 404.

- [ ] **Step 9: Run focused tests and commit the atomic migration**

Run:

```bash
bin/rails test \
  test/models/writing/publication_policy_test.rb \
  test/models/writing/catalogue_test.rb \
  test/integration/writing_publication_access_test.rb \
  test/integration/feed_publication_test.rb \
  test/integration/writing_collection_test.rb \
  test/integration/writing_latest_list_test.rb \
  test/integration/pages_smoke_test.rb
```

Expected: all focused tests pass.

```bash
git add app/models/writing app/controllers/sitepress/site_controller.rb app/controllers/feed_controller.rb app/content/pages/writing app/content/templates test/models/writing test/integration
git commit -m "feat(writing): adopt folder-based publication"
```

## Task 4: Make Cover Generation Understand Dated Posts

**Files:**
- Modify: `lib/post_image_generator.rb`
- Modify: `lib/tasks/post_images.rake`
- Create: `test/lib/post_image_generator_test.rb`

- [ ] **Step 1: Write a failing dated-cover test**

Create a temporary dated post and assert its output filename is `example.svg`, not `2024-03-10-example.svg`. Add a draft assertion and preserve deterministic output behavior.

- [ ] **Step 2: Run the focused cover test and confirm it fails**

Run: `bin/rails test test/lib/post_image_generator_test.rb`

Expected: the dated output currently retains the date prefix.

- [ ] **Step 3: Reuse `Writing::Path` in the generator**

Require the shared parser and derive the cover slug from it. Change the rake glob to include both `writing/drafts/*` and `writing/posts/*`, while excluding templates and nested non-post content.

- [ ] **Step 4: Verify and commit**

Run: `bin/rails test test/lib/post_image_generator_test.rb`

Expected: all focused tests pass and temporary files are cleaned up.

```bash
git add lib/post_image_generator.rb lib/tasks/post_images.rake test/lib/post_image_generator_test.rb
git commit -m "fix(writing): preserve cover slugs for dated posts"
```

## Task 5: Update the Authoring Command and Contributor Documentation

**Files:**
- Modify: `go`
- Modify: `CLAUDE.md`
- Create: `test/scripts/go_write_test.sh`

- [ ] **Step 1: Write a failing shell-level authoring test**

In a temporary project skeleton, copy `go` and the writing template, pipe `My New Post` into `./go write`, and assert:

- `app/content/pages/writing/drafts/my-new-post.makerb` exists.
- its title is populated.
- no flat writing file or dated post was created.

Use a trap to remove the exact temporary directory.

- [ ] **Step 2: Run the script test and confirm it fails**

Run: `bash test/scripts/go_write_test.sh`

Expected: the current command looks for the old template and flat destination.

- [ ] **Step 3: Update `./go write`**

Create the drafts directory if needed, read the template from `app/content/templates/writing.makerb`, refuse to overwrite an existing draft, and report the full draft path. Preserve cross-platform `sed` behavior.

- [ ] **Step 4: Document drafting, publishing, scheduling, and withdrawing**

Update `CLAUDE.md` with the exact directory convention and `git mv` examples. State that dates use Brussels publication days, future dates schedule automatically, draft/scheduled previews are development-only, and legacy publication keys are forbidden.

- [ ] **Step 5: Verify and commit**

Run: `bash test/scripts/go_write_test.sh`

Expected: pass.

```bash
git add go CLAUDE.md test/scripts/go_write_test.sh
git commit -m "docs(writing): define folder-based authoring workflow"
```

## Task 6: Full Verification and Review

**Files:**
- Modify only files required by failures or review findings.

- [ ] **Step 1: Run all Ruby tests**

Run: `bin/rails test`

Expected: zero failures and zero errors.

- [ ] **Step 2: Run the production image smoke test**

Run: `bash test/scripts/run_production_image_test.sh`

Expected: production boots and the script passes without leaking drafts or scheduled resources.

- [ ] **Step 3: Run the authoring workflow test**

Run: `bash test/scripts/go_write_test.sh`

Expected: pass.

- [ ] **Step 4: Inspect the final diff and content tree**

Run:

```bash
git status --short
git diff --check
find app/content/pages/writing -maxdepth 2 -type f | sort
rg -n '^(status|published|publish_at):' app/content/pages/writing
```

Expected: only intended changes, no whitespace errors, every writing resource under `drafts/` or `posts/`, and the final `rg` returns no matches.

- [ ] **Step 5: Request a focused code review**

Ask the reviewer to check the implementation against the design, with special attention to Sitepress tree lifetime, production 404 behavior, Brussels DST boundaries, duplicate validation, and stable URLs.

- [ ] **Step 6: Address findings and rerun affected plus full verification**

Do not claim completion from stale test output. Rerun `bin/rails test`, both shell tests, and `git diff --check` after the final change.

- [ ] **Step 7: Commit any final review corrections**

```bash
git add <reviewed-files>
git commit -m "fix(writing): address publication workflow review"
```
