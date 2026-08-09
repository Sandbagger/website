# Generated Topic Archives Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn strict writing topic arrays into linked, publication-safe archive pages backed by generated Sitepress 5 resources.

**Architecture:** A small immutable `Writing::Topic` value object owns topic validation, slugs, and URLs. The existing writing resource pipeline performs a complete topic preflight before tree mutation, then adds `Writing::TopicPage` sources below `/writing/topics`; the catalogue remains the publication authority and Phlex components render the resulting links and archives.

**Tech Stack:** Ruby 3.3, Rails 8, Sitepress 5.0.0.beta4, Literal, Phlex, Minitest, Bash

---

## File structure

- Create `lib/writing/topic.rb`: immutable topic identity plus strict conversion from Sitepress frontmatter.
- Create `lib/writing/topic_page.rb`: generated native `Sitepress::Page` source for one topic archive.
- Create `app/content/templates/topic.markerb`: shared empty Markerb body for generated topic sources.
- Create `app/views/components/topic_links_component.rb`: reusable linked-topic renderer.
- Create `test/lib/writing/topic_test.rb`: topic identity and strict metadata contract.
- Create `test/lib/writing/topic_page_test.rb`: generated source behavior.
- Create `test/components/topic_links_component_test.rb`: linked topic markup.
- Create `test/integration/writing_topic_archives_test.rb`: routing, publication, ordering, and source-tree coverage.
- Modify `lib/writing/resource_pipeline.rb`: preflight topic metadata and generate collision-safe topic resources.
- Modify `config/initializers/sitepress_writing.rb`: load topic classes and provide the topic template.
- Modify `app/models/writing/catalogue.rb`: filter published entries by a `Writing::Topic`.
- Modify `app/controllers/sitepress/site_controller.rb`: pass typed topics and render topic archives.
- Modify `app/views/components/collection_component.rb`: replace comma parsing with linked topics.
- Modify `app/views/layouts/application_layout.rb`: accept typed topic arrays and render links in both article metadata locations.
- Modify writing content under `app/content/pages/writing/{posts,drafts}`: migrate to canonical `topic` YAML arrays and repair the one `topics`/`date` outlier.
- Modify `app/content/templates/writing.makerb`, `go`, and `test/scripts/go_write_test.sh`: create valid topic arrays for new drafts.
- Modify affected tests that construct writing resources: provide canonical topic arrays.
- Modify `CLAUDE.md`: document the required topic prompt and array format.

### Task 1: Add immutable topic identity and strict metadata conversion

**Files:**
- Create: `lib/writing/topic.rb`
- Create: `test/lib/writing/topic_test.rb`

- [ ] **Step 1: Write failing value-object tests**

Create `test/lib/writing/topic_test.rb` with focused tests demonstrating the intended API:

```ruby
# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/writing/topic")

class Writing::TopicTest < ActiveSupport::TestCase
  test "retains its curated label and derives a stable archive path" do
    topic = Writing::Topic.new(label: "Ruby on Rails")

    assert_equal "Ruby on Rails", topic.label
    assert_equal "ruby-on-rails", topic.slug
    assert_equal "/writing/topics/ruby-on-rails", topic.request_path
    assert_equal topic, Writing::Topic.new(label: "Ruby on Rails")
    assert_predicate topic, :frozen?
    assert_predicate topic.label, :frozen?
  end

  test "converts a Sitepress topic array into immutable topics" do
    data = Sitepress::Data.manage("topic" => ["Ruby on Rails", "Phlex"])

    topics = Writing::Topic.from(data, source_path: "example.markerb")

    assert_equal ["Ruby on Rails", "Phlex"], topics.map(&:label)
    assert_predicate topics, :frozen?
  end

  test "rejects scalar topic metadata with the source path" do
    data = Sitepress::Data.manage("topic" => "Ruby, Rails")

    error = assert_raises(Writing::Topic::Invalid) do
      Writing::Topic.from(data, source_path: "example.markerb")
    end

    assert_includes error.message, "example.markerb"
    assert_includes error.message, "YAML array"
  end
end
```

Add separate tests for a missing key, an empty array, non-string members,
blank/padded labels, case-insensitive duplicates, and labels whose
`parameterize` result is empty.

- [ ] **Step 2: Run the topic tests and verify RED**

Run:

```bash
PARALLEL_WORKERS=1 bin/rails test test/lib/writing/topic_test.rb
```

Expected: ERROR because `Writing::Topic` is undefined.

- [ ] **Step 3: Implement the minimal topic object**

Create `lib/writing/topic.rb`:

```ruby
# frozen_string_literal: true

module Writing
  class Topic < Literal::Data
    class Invalid < StandardError; end

    prop :label, String

    def self.from(data, source_path:)
      labels = data.fetch("topic")
      invalid!(source_path, "topic must be a non-empty YAML array") unless labels.is_a?(Sitepress::Data::Collection)

      topics = labels.map.with_index do |label, index|
        invalid!(source_path, "topic[#{index}] must be a String") unless label.is_a?(String)
        new(label: label)
      rescue Invalid => error
        invalid!(source_path, "topic[#{index}] #{error.message}")
      end
      invalid!(source_path, "topic must not be empty") if topics.empty?
      duplicates = topics.group_by { _1.label.downcase }.values.find { _1.many? }
      invalid!(source_path, "topics must be unique ignoring case") if duplicates

      topics.freeze
    rescue KeyError
      invalid!(source_path, "missing topic YAML array")
    end

    def self.invalid!(source_path, message)
      fail Invalid, "Invalid writing topics in #{source_path.inspect}: #{message}"
    end
    private_class_method :invalid!

    def slug = label.parameterize

    def request_path = "/writing/topics/#{slug}"

    private

    def after_initialize
      fail Invalid, "must be nonblank without surrounding whitespace" if label.blank? || label != label.strip
      fail Invalid, "must produce a nonblank URL slug" if slug.blank?

      @label = label.dup.freeze
    end
  end
end
```

Keep error wording deterministic and make the final implementation satisfy all
tests; do not accept strings or silently normalize hand-authored frontmatter.

- [ ] **Step 4: Run the topic tests and verify GREEN**

Run the command from Step 2.

Expected: all `Writing::TopicTest` tests pass with zero failures.

- [ ] **Step 5: Commit the topic object**

```bash
git add lib/writing/topic.rb test/lib/writing/topic_test.rb
git commit -m "feat(writing): Add strict topic identity"
```

### Task 2: Enforce topic arrays during atomic writing preflight

**Files:**
- Modify: `lib/writing/resource_pipeline.rb`
- Modify: `config/initializers/sitepress_writing.rb`
- Modify: `test/lib/writing/resource_pipeline_test.rb`
- Modify: `test/integration/writing_boot_validation_test.rb`
- Modify: `test/integration/writing_resource_mapping_test.rb`
- Modify: `test/integration/feed_publication_test.rb`
- Modify: writing files below `app/content/pages/writing/posts/`
- Modify: writing files below `app/content/pages/writing/drafts/`

- [ ] **Step 1: Update pipeline fixtures and write failing preflight tests**

Require `lib/writing/topic` from `config/initializers/sitepress_writing.rb`.
Update every pipeline test helper that creates a writing page (`add_resource`
and `add_resource_at`) so ordinary writing resources receive
`{"topic" => ["Ruby"]}` by default, while individual validation tests can pass
an exact data hash.

Extend `Writing::ResourcePipeline::Entry` expectations to include a frozen
`topics` array. Add one test per behavior:

- scalar, missing, empty, padded, non-string, and duplicate topic metadata fail;
- failures mention the physical source path;
- differing capitalization for the same label across resources fails;
- different labels producing the same slug fail;
- every failure leaves `tree_snapshot(root)` unchanged in production and test.

Use examples such as `"Ruby"` versus `"ruby"` for inconsistent display labels
and `"C"` versus `"C++"` for slug collisions.

- [ ] **Step 2: Run the pipeline tests and verify RED**

```bash
PARALLEL_WORKERS=1 bin/rails test test/lib/writing/resource_pipeline_test.rb
```

Expected: FAIL because entries do not contain topics and the pipeline accepts
invalid topic metadata.

- [ ] **Step 3: Parse topics before all tree mutation**

In `Writing::ResourcePipeline`:

- add `prop :topics, _Array(Writing::Topic)` to `Entry`;
- construct every entry with `Writing::Topic.from(resource.data,
  source_path: resource.source.path)`;
- translate `Writing::Topic::Invalid` into `ResourcePipeline::Invalid` while
  retaining the detailed message;
- validate a global registry before `entries.each { |entry| apply(...) }`;
- reject inconsistent capitalization and slug collisions across all entries,
  including production drafts;
- keep legacy metadata, slug, and canonical-target validation in the same
  pre-mutation phase.

The process shape should remain visibly two-phase:

```ruby
entries = build_entries(root)
validate_entries!(root, entries)
entries.each { apply(root, _1) }
```

Do not add generated resources yet.

- [ ] **Step 4: Migrate all real and temporary writing content**

Convert every scalar value to a curated YAML array. Use consistent labels such
as `Ruby on Rails`, `Sitepress`, `Phlex`, `Ruby`, `Analytics`, `CSS`,
`Asset Pipeline`, `Tailwind`, `Tariffs`, and `Macroeconomics`.

For `why-I-made-this-site-with-phlex-sitepress-and-rails.html.markerb`, remove
the disallowed `date` key, rename `topics` to singular `topic`, and emit the
same array form.

Update temporary writing fixtures in boot validation, resource mapping, and
feed publication tests to contain a valid topic array. Keep the legacy-key boot
fixture valid apart from its intentional `status` violation so it still tests
the intended error.

- [ ] **Step 5: Run focused validation and integration tests**

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/lib/writing/resource_pipeline_test.rb \
  test/integration/writing_boot_validation_test.rb \
  test/integration/writing_resource_mapping_test.rb \
  test/integration/feed_publication_test.rb
```

Expected: all selected tests pass with zero failures.

- [ ] **Step 6: Commit strict pipeline ingestion and content migration**

```bash
git add lib/writing/resource_pipeline.rb config/initializers/sitepress_writing.rb \
  test/lib/writing/resource_pipeline_test.rb \
  test/integration/writing_boot_validation_test.rb \
  test/integration/writing_resource_mapping_test.rb \
  test/integration/feed_publication_test.rb \
  app/content/pages/writing
git commit -m "feat(writing): Require canonical topic arrays"
```

### Task 3: Generate native Sitepress topic resources

**Files:**
- Create: `lib/writing/topic_page.rb`
- Create: `app/content/templates/topic.markerb`
- Create: `test/lib/writing/topic_page_test.rb`
- Modify: `lib/writing/resource_pipeline.rb`
- Modify: `config/initializers/sitepress_writing.rb`
- Modify: `test/lib/writing/resource_pipeline_test.rb`
- Modify: `test/integration/writing_resource_mapping_test.rb`
- Modify: `test/integration/feed_publication_test.rb`

- [ ] **Step 1: Write failing generated-source and pipeline tests**

Test `Writing::TopicPage` with a real template path. Require that it:

- is a `Sitepress::Page`;
- exposes `layout: "topic"`, `topic_label`, `topic_slug`, and a title;
- uses the shared Markerb body;
- remains renderable when wrapped by an HTML `Sitepress::Resource`.

Add pipeline tests asserting:

```ruby
topic_resource = root.get("/writing/topics/ruby")
assert_instance_of Writing::TopicPage, topic_resource.source
assert_equal :html, topic_resource.format
assert_equal :markerb, topic_resource.handler
```

Also cover de-duplication, a collision with an existing
`/writing/topics/<slug>` resource before mutation, production draft-only topic
exclusion, scheduled-topic generation, and a missing template failure before
mutation.

- [ ] **Step 2: Run the generated-resource tests and verify RED**

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/lib/writing/topic_page_test.rb \
  test/lib/writing/resource_pipeline_test.rb
```

Expected: ERROR/FAIL because `Writing::TopicPage` and generated topic resources
do not exist.

- [ ] **Step 3: Implement the generated page source**

Create `lib/writing/topic_page.rb` as a focused `Sitepress::Page` subclass:

```ruby
# frozen_string_literal: true

module Writing
  class TopicPage < Sitepress::Page
    attr_reader :topic

    def initialize(path:, topic:)
      @topic = topic
      super(path: path)
    end

    def data
      @data ||= Sitepress::Data.manage(
        "layout" => "topic",
        "title" => "Writing about #{topic.label}",
        "topic_label" => topic.label,
        "topic_slug" => topic.slug
      )
    end
  end
end
```

Create `app/content/templates/topic.markerb` with an intentionally empty body
and a short comment explaining that the controller supplies the archive rows.

- [ ] **Step 4: Add collision preflight and generation to the pipeline**

Give `ResourcePipeline` a required `topic_template_path:` initializer keyword;
pass `Sitepress.site.root_path.join("templates/topic.markerb")` from the
initializer and explicit template paths from every pipeline constructor in the
resource-pipeline, resource-mapping, and feed-publication tests.

Before mutation, validate that the template is a file and every unique topic's
target is free. After draft/post mutation, select entries with:

```ruby
entry.path.post? || environment != "production"
```

De-duplicate their topics by slug, materialize
`/writing/topics/<slug>`, and add a `Sitepress::Resource` with `source:`, HTML
format, and the native Markerb handler inferred from the source path. Do not use
`asset:` anywhere in application code.

- [ ] **Step 5: Run generated-resource tests and verify GREEN**

Run the command from Step 2.

Expected: all selected tests pass with zero failures.

- [ ] **Step 6: Commit generated Sitepress sources**

```bash
git add lib/writing/topic_page.rb app/content/templates/topic.markerb \
  lib/writing/resource_pipeline.rb config/initializers/sitepress_writing.rb \
  test/lib/writing/topic_page_test.rb test/lib/writing/resource_pipeline_test.rb \
  test/integration/writing_resource_mapping_test.rb \
  test/integration/feed_publication_test.rb
git commit -m "feat(sitepress): Generate topic archive resources"
```

### Task 4: Filter the published catalogue by topic

**Files:**
- Modify: `app/models/writing/catalogue.rb`
- Modify: `test/models/writing/catalogue_test.rb`

- [ ] **Step 1: Write failing catalogue topic tests**

Update catalogue fixtures to carry topic arrays and extend `Catalogue::Entry`
with typed topics. Add tests proving that `published(topic:)`:

- returns only posts containing the exact `Writing::Topic` identity;
- still excludes drafts and future-dated posts before topic filtering;
- preserves descending publication order;
- composes with `exclude:`;
- ignores generated topic pages and unrelated Sitepress resources.

- [ ] **Step 2: Run the catalogue tests and verify RED**

```bash
PARALLEL_WORKERS=1 bin/rails test test/models/writing/catalogue_test.rb
```

Expected: FAIL because `published` does not accept `topic:`.

- [ ] **Step 3: Implement topic-aware entries and filtering**

Add `topics: _Array(Writing::Topic)` to `Catalogue::Entry`, populate it from
the validated resource data, and change the public signature to:

```ruby
def published(exclude: nil, topic: nil)
```

Apply publication policy first, then optional topic membership, exclusion,
date ordering, and resource projection. Continue rescuing `Writing::Path::Invalid`
before topic parsing so generated topic pages stay outside the catalogue.

- [ ] **Step 4: Run the catalogue tests and verify GREEN**

Run the command from Step 2.

Expected: all catalogue tests pass.

- [ ] **Step 5: Commit catalogue filtering**

```bash
git add app/models/writing/catalogue.rb test/models/writing/catalogue_test.rb
git commit -m "feat(writing): Filter published posts by topic"
```

### Task 5: Render consistent linked topic metadata

**Files:**
- Create: `app/views/components/topic_links_component.rb`
- Create: `test/components/topic_links_component_test.rb`
- Modify: `app/views/components/collection_component.rb`
- Modify: `test/components/collection_component_test.rb`
- Modify: `app/views/layouts/application_layout.rb`
- Modify: `test/views/layouts/application_layout_test.rb`
- Modify: `app/controllers/sitepress/site_controller.rb`
- Modify: `test/integration/article_layout_test.rb`
- Modify: `test/integration/writing_publication_access_test.rb`

- [ ] **Step 1: Write failing component and layout tests**

Specify a `TopicLinksComponent` that renders ordered anchors separated by
literal ` · ` text and renders nothing for an empty collection. Assert exact
labels and hrefs.

Replace the collection component's numeric/scalar-topic test with a strict
array test asserting links. Extend the article integration test to require
topic anchors in both `.article-header .article-meta` and
`.article-facts dd`, without changing the published date text.

- [ ] **Step 2: Run the presentation tests and verify RED**

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/components/topic_links_component_test.rb \
  test/components/collection_component_test.rb \
  test/views/layouts/application_layout_test.rb \
  test/integration/article_layout_test.rb
```

Expected: FAIL because topic labels are still unlinked scalar text.

- [ ] **Step 3: Implement shared topic links**

Create the Phlex component:

```ruby
# frozen_string_literal: true

class TopicLinksComponent < ApplicationComponent
  def initialize(topics)
    @topics = topics
  end

  def view_template
    @topics.each_with_index do |topic, index|
      plain " · " if index.positive?
      a(href: topic.request_path) { topic.label }
    end
  end
end
```

In `CollectionComponent`, convert the trusted resource data through
`Writing::Topic.from` and render the component inside `.article-meta`; write
the date separator only when both topics and date are present.

Change `ApplicationLayout#page_metadata` from `topic:` to `topics:` and render
the same component in the header and facts rail. Remove all comma splitting.
Update the Sitepress controller to pass typed topics for articles.
Update temporary article resources in `writing_publication_access_test.rb` to
contain a canonical topic array before exercising the controller.

- [ ] **Step 4: Run the presentation tests and verify GREEN**

Run the command from Step 2.

Expected: all selected tests pass with exact canonical topic links.

- [ ] **Step 5: Commit linked metadata**

```bash
git add app/views/components/topic_links_component.rb \
  test/components/topic_links_component_test.rb \
  app/views/components/collection_component.rb \
  test/components/collection_component_test.rb \
  app/views/layouts/application_layout.rb \
  test/views/layouts/application_layout_test.rb \
  app/controllers/sitepress/site_controller.rb \
  test/integration/article_layout_test.rb \
  test/integration/writing_publication_access_test.rb
git commit -m "feat(writing): Link article topic metadata"
```

### Task 6: Render publication-safe topic archive pages

**Files:**
- Create: `test/integration/writing_topic_archives_test.rb`
- Modify: `app/controllers/sitepress/site_controller.rb`
- Modify: `test/integration/pages_smoke_test.rb` only if its generated test names need adjustment

- [ ] **Step 1: Write failing topic archive integration tests**

Against the real site, assert that `/writing/topics/phlex`:

- resolves to a `Writing::TopicPage` source;
- retains the canonical resource request path `/writing/topics/phlex`;
- responds successfully;
- has `main.page--archive` and `h1` text `Writing about Phlex`;
- lists the two published Phlex posts newest first;
- excludes drafts and posts belonging to other topics.

Assert that the draft-only `/writing/topics/css` resource exists in the test
tree but responds 404 because it has no published posts.

Build a temporary cached site containing one scheduled-only topic and use the
existing mutable Brussels clock pattern to prove that the same generated
resource returns 404 before midnight and success after midnight without a tree
reload.

- [ ] **Step 2: Run the integration test and verify RED**

```bash
PARALLEL_WORKERS=1 bin/rails test test/integration/writing_topic_archives_test.rb
```

Expected: FAIL because `topic_layout` does not exist.

- [ ] **Step 3: Implement the topic layout**

In `Sitepress::SiteController`, add a `topic_layout(page)` method that:

1. reconstructs the requested `Writing::Topic` from `topic_label`;
2. asks `catalogue.published(topic:)` at request time;
3. raises `Sitepress::ResourceNotFound` when the collection is empty;
4. configures `ApplicationLayout` with archive page kind and the generated
   title;
5. renders the shared topic Markerb body and an archive-context
   `CollectionComponent`.

Change the private `published` helper to accept `topic: nil` while retaining
the current request-path exclusion for article tails.

- [ ] **Step 4: Run topic and publication tests and verify GREEN**

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/integration/writing_topic_archives_test.rb \
  test/integration/writing_publication_access_test.rb \
  test/integration/writing_collection_test.rb \
  test/integration/pages_smoke_test.rb
```

Expected: all selected tests pass; the scheduled topic changes visibility
without rebuilding the Sitepress tree.

- [ ] **Step 5: Commit topic rendering**

```bash
git add app/controllers/sitepress/site_controller.rb \
  test/integration/writing_topic_archives_test.rb \
  test/integration/pages_smoke_test.rb
git commit -m "feat(writing): Render topic archive pages"
```

Omit `pages_smoke_test.rb` from the commit if it required no edit.

### Task 7: Scaffold valid topic arrays for new drafts

**Files:**
- Modify: `go`
- Modify: `app/content/templates/writing.makerb`
- Modify: `test/scripts/go_write_test.sh`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Write failing shell tests for topic prompting**

Change the shell helper to provide both a title and a topic-input line. Add an
`assert_yaml_topics` helper and cases for:

- trimming `Ruby on Rails, Sitepress` into two YAML array strings;
- JSON/YAML-significant characters round-tripping safely;
- empty input, blank members, and case-insensitive duplicates failing without
  a draft or temporary file;
- EOF while reading topics failing atomically;
- a template missing the canonical topic example block failing cleanly.

Preserve all existing collision, permissions, dangling symlink, copy failure,
and title substitution cases.

- [ ] **Step 2: Run the shell test and verify RED**

```bash
bash test/scripts/go_write_test.sh
```

Expected: FAIL because `go write` never prompts for or populates topics.

- [ ] **Step 3: Implement topic input and atomic substitution**

After validating the title and before creating directories or temporary files,
prompt once for comma-separated topics. Use a small Ruby process to:

- split with trailing empty fields preserved;
- trim CLI input;
- reject an empty list, blank members, and case-insensitive duplicates;
- return JSON for safe passage back to the substitution process.

Change `writing.makerb` to contain a valid example:

```yaml
topic:
  - Topic
```

Extend the existing atomic Ruby substitution so it replaces both the title and
the complete example topic block, emitting each topic with `JSON.generate`
(valid YAML scalar syntax). Any validation or substitution error must occur
before final `mv` and must clean the temporary file.

Update `CLAUDE.md` to state that `./go write` asks for title and topics and that
hand-authored `topic` values must be non-empty YAML arrays.

- [ ] **Step 4: Run scaffold tests and verify GREEN**

```bash
bash test/scripts/go_write_test.sh
bash test/scripts/go_test.sh
```

Expected: both scripts pass with zero errors.

- [ ] **Step 5: Commit draft scaffolding**

```bash
git add go app/content/templates/writing.makerb \
  test/scripts/go_write_test.sh CLAUDE.md
git commit -m "feat(writing): Scaffold canonical topic arrays"
```

### Task 8: Full verification and strict API audit

**Files:**
- Modify only files required to correct verification failures

- [ ] **Step 1: Run the complete Rails suite**

```bash
bin/rails test
```

Expected: all tests pass with zero failures and zero errors.

- [ ] **Step 2: Run the complete formatter/linter**

```bash
bundle exec standardrb
```

Expected: exit 0 with no offenses.

- [ ] **Step 3: Verify production-style boot**

```bash
RAILS_ENV=test bin/rails runner 'puts "booted"'
```

Expected: prints `booted` and exits 0.

- [ ] **Step 4: Audit topic content and native Sitepress APIs**

```bash
rg -n '^topics:|^topic:\s*[^[:space:]-]' app/content/pages/writing
rg -n '\basset\b|asset:' app/controllers app/models app/views lib/writing config/initializers/sitepress_writing.rb
bin/rails runner '
  topics = Sitepress.site.resources.select { _1.source.is_a?(Writing::TopicPage) }
  abort "no generated topics" if topics.empty?
  abort "non-native topic source" unless topics.all? { _1.source.is_a?(Sitepress::Page) }
  puts topics.map(&:request_path).sort
'
```

Expected: the first search has no matches, the second search introduces no
application compatibility calls, and the runner prints canonical topic paths.
If unrelated existing `asset` text appears, inspect it rather than deleting it
blindly.

- [ ] **Step 5: Inspect the final branch**

```bash
git status --short
git log --oneline --decorate -10
git diff main...HEAD --check
git diff --stat main...HEAD
```

Expected: a clean feature worktree, the planned commits, no whitespace errors,
and only generated-topic-archive changes.

- [ ] **Step 6: Request code review before integration**

Invoke `superpowers-ruby:requesting-code-review`, address any correctness
findings, repeat the full verification commands, then use
`superpowers-ruby:finishing-a-development-branch` to choose integration or PR
handling.
