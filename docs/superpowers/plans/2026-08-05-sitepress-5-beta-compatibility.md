# Sitepress 5 Beta Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the Rails application to `sitepress-rails` `5.0.0.beta4` while preserving every existing content, routing, publication and rendering behavior.

**Architecture:** Pin the published beta exactly, let the existing integration suite expose removed APIs, and make only the known PageModel compatibility change plus any further change demonstrated by a failing contract test. Keep the custom Sitepress controller and `Writing::ResourcePipeline` on the beta's supported backwards-compatible `asset` API; do not adopt multi-site, source mounting or the standalone server.

**Tech Stack:** Ruby 3.3.5, Rails 8.0, Bundler, Sitepress Rails/Core 5.0 beta, Minitest, Capybara/Selenium, StandardRB

---

## File Map

- Modify `Gemfile`: pin the exact Sitepress beta so dependency resolution cannot drift to another prerelease or final release.
- Modify `Gemfile.lock`: record Sitepress beta and transitive dependency resolution.
- Modify `app/content/models/page_model.rb`: replace the removed keyword collection declaration with the supported Sitepress 5 class method.
- Test existing files under `test/lib/writing/`, `test/models/writing/`, `test/integration/` and `test/system/`; add a test only if a compatibility requirement is discovered that these contracts do not cover.

### Task 1: Establish the migration failure against Sitepress beta4

**Files:**
- Modify: `Gemfile:81`
- Modify: `Gemfile.lock`
- Reference: `app/content/models/page_model.rb:1-4`

- [ ] **Step 1: Run the focused integration baseline on Sitepress 4.1.1**

Run:

```bash
bin/rails test \
  test/lib/writing/resource_pipeline_test.rb \
  test/models/writing/catalogue_test.rb \
  test/integration/writing_resource_mapping_test.rb \
  test/integration/writing_boot_validation_test.rb \
  test/integration/writing_publication_access_test.rb \
  test/integration/writing_collection_test.rb \
  test/integration/feed_publication_test.rb \
  test/integration/pages_smoke_test.rb
```

Expected: PASS. This establishes that any subsequent failure comes from the beta migration rather than the pre-existing integration.

Before editing, inspect the existing lockfile delta:

```bash
git diff -- Gemfile.lock
```

Expected: the only pre-existing lockfile change is the already verified Sitepress
4.0.2-to-4.1.1 update. Preserve that intent when resolving beta4; do not discard
or stage unrelated worktree changes.

- [ ] **Step 2: Pin the exact beta in `Gemfile`**

Replace:

```ruby
gem "sitepress-rails", "~> 4.0"
```

with:

```ruby
gem "sitepress-rails", "5.0.0.beta4"
```

An exact beta pin is intentional: do not use `~> 5.0.0.beta4`.

- [ ] **Step 3: Resolve only the Sitepress dependency family**

Run:

```bash
bundle update --conservative sitepress-rails sitepress-core
```

Expected: Bundler installs `sitepress-rails 5.0.0.beta4` and its exact `sitepress-core 5.0.0.beta4` dependency, retains the existing Rails 8 constraint, and updates only dependencies required by that resolution.

- [ ] **Step 4: Verify the known removed PageModel API fails before application compatibility code changes**

Run:

```bash
bin/rails runner 'puts PageModel.all.count'
```

Expected: FAIL during application/model loading because Sitepress 5's `collection` requires a block and no longer accepts `collection glob: ...`. Record the exact error before continuing. If it fails earlier for another reason, invoke `superpowers-ruby:systematic-debugging` and find that root cause before editing application code.

### Task 2: Apply the minimal PageModel compatibility migration

**Files:**
- Modify: `app/content/models/page_model.rb:1-4`
- Test: existing focused tests listed in Task 1

- [ ] **Step 1: Replace the removed collection declaration**

Change `PageModel` to:

```ruby
class PageModel < Sitepress::Model
  def self.all = glob("**/*.html*")

  data :title
end
```

Do not change the glob, model data declarations or callers.

- [ ] **Step 2: Verify Rails boots with the beta and PageModel collection**

Run:

```bash
bin/rails runner '
  puts "sitepress-rails #{Gem.loaded_specs.fetch("sitepress-rails").version}"
  puts "sitepress-core #{Gem.loaded_specs.fetch("sitepress-core").version}"
  puts "pages #{PageModel.all.count}"
'
```

Expected: exit 0; both gems report `5.0.0.beta4`; PageModel returns a count without a removed-API error.

- [ ] **Step 3: Run the focused compatibility suite**

Run the Task 1 focused test command again.

Expected: PASS with zero failures and errors. This verifies the custom resource pipeline, legacy `asset` alias, canonical paths, publication access, feed generation, collections and rendering.

- [ ] **Step 4: Investigate any newly exposed incompatibility test-first**

If Step 3 fails, invoke `superpowers-ruby:systematic-debugging`. Trace the failure to the Sitepress 5 API delta, confirm whether an existing test expresses the required behavior, and add a minimal failing regression test only when coverage is missing. Make one compatibility change at a time and rerun the narrow test until green. Do not modernize to `source`, directories, mounts or multi-site APIs.

- [ ] **Step 5: Inspect dependency and source scope**

Run:

```bash
git diff -- Gemfile Gemfile.lock app/content/models/page_model.rb app/controllers/sitepress/site_controller.rb lib/writing/resource_pipeline.rb
```

Expected: the Gemfile pin, lockfile resolution and PageModel syntax are the only changes unless a focused failing test required another compatibility fix.

### Task 3: Verify the complete application

**Files:**
- Verify: all migration files from Task 2
- Preserve: unrelated dirty worktree files

- [ ] **Step 1: Run the complete Rails test suite**

Run:

```bash
bin/rails test
```

Expected: PASS with zero failures and errors. If the sandbox blocks Rails' DRb socket for parallel tests, rerun the same command with the required local-socket permission; do not alter test parallelization.

- [ ] **Step 2: Run the complete system test suite**

Run:

```bash
bin/rails test:system
```

Expected: PASS with zero failures and errors. This confirms browser-visible layouts and navigation remain unchanged.

If either full suite fails, invoke `superpowers-ruby:systematic-debugging`, reproduce
the narrow failure, and follow the test-first compatibility loop from Task 2 Step
4. Rerun the narrow test, the focused suite, the full suite and the system suite
after the fix. Do not commit while any verification is failing.

- [ ] **Step 3: Run formatting and dependency verification**

Run:

```bash
bundle exec standardrb
bundle check
git diff --check
```

Expected: every command exits 0.

- [ ] **Step 4: Verify the final versions and worktree scope**

Run:

```bash
bin/rails runner '
  abort unless Gem.loaded_specs.fetch("sitepress-rails").version.to_s == "5.0.0.beta4"
  abort unless Gem.loaded_specs.fetch("sitepress-core").version.to_s == "5.0.0.beta4"
  puts "Sitepress beta4 verified"
'
git status --short
git diff --stat
```

Expected: the version check exits 0; the pending migration diff contains only
intended files; pre-existing unrelated worktree changes remain unstaged and
untouched.

- [ ] **Step 5: Commit the verified compatibility upgrade**

Stage only migration files and commit using the repository's Ruby commit-message workflow:

```bash
git add Gemfile Gemfile.lock app/content/models/page_model.rb
git commit -m "build(sitepress): Upgrade to 5.0 beta4"
```

If the compatibility loop required another production or test file, include only
that demonstrated migration file. Do not stage `.DS_Store`, the user's modified
typed-frontmatter specification or other unrelated worktree changes.

- [ ] **Step 6: Review completion evidence**

Invoke `superpowers-ruby:verification-before-completion`. Report exact focused, full and system test counts, formatting/dependency results, the final Sitepress versions, the migration commit and any preserved unrelated files. Do not claim completion from earlier or partial output.
