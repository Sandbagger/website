# Typed Writing Frontmatter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace repeated Sitepress frontmatter reads with a closed, immutable `Writing::Frontmatter` value and a narrow `Writing::Article` facade throughout writing ingestion, publication, and presentation.

**Architecture:** `Writing::Frontmatter` validates Sitepress data once and owns sealed scalar and topic values; `Writing::Article` combines it with a newly immutable `Writing::Path` without retaining the Sitepress resource. The pipeline validates every article before tree mutation, while the catalogue, publication policy, controllers, component, cover lookup, and feed consume only the article facade.

**Tech Stack:** Ruby 3.3.5, Rails 8, Sitepress 5.0.0.beta4, Literal 1.9.0 at `e51ef7c3e6a03127977acc06071a020b497be24e`, Phlex, Minitest, Bash, Standard Ruby

---

## File map

- Create `lib/writing/frontmatter.rb`: closed Sitepress-data ingestion, deterministic diagnostics, and immutable title/topic/emoji ownership.
- Create `test/lib/writing/frontmatter_test.rb`: schema, error-order, cause, equality/hash, and seal coverage.
- Create `lib/writing/article.rb`: resource-to-domain projection and the explicit writing facade.
- Create `test/lib/writing/article_test.rb`: facade, identity, freezing, stable paths, and resource-detachment coverage.
- Modify `lib/writing/path.rb` and `test/lib/writing/path_test.rb`: own parsed strings and freeze successful paths.
- Modify `config/initializers/sitepress_writing.rb`: load Frontmatter and Article before the resource pipeline.
- Modify `lib/writing/resource_pipeline.rb` and `test/lib/writing/resource_pipeline_test.rb`: preflight Articles, remove duplicate path/topic state, and eventually stop amending resource data.
- Modify `test/integration/writing_boot_validation_test.rb`: prove closed-schema failures abort boot.
- Modify `app/models/writing/catalogue.rb` and `test/models/writing/catalogue_test.rb`: remove the private Entry and return Articles.
- Modify `app/models/writing/publication_policy.rb` and `test/models/writing/publication_policy_test.rb`: evaluate the Article interface.
- Modify `app/controllers/sitepress/site_controller.rb`: use Articles for writing access and layout metadata while preserving generic Sitepress behavior for non-writing pages.
- Modify `app/views/components/collection_component.rb` and `test/components/collection_component_test.rb`: render Article readers only.
- Modify `app/views/layouts/application_layout.rb` and `test/views/layouts/application_layout_test.rb`: carry `publication_date` rather than pipeline-derived `publish_at` presentation state.
- Modify `app/views/feed/index.xml.builder` and feed tests: render Article readers only.
- Modify `test/integration/writing_publication_access_test.rb` and affected writing integration tests: stop injecting or asserting derived `publish_at` data.
- Modify `go` and `test/scripts/go_write_test.sh`: trim and validate titles before slugging and serialization.
- Verify current files below `app/content/pages/writing/{drafts,posts}` against the new closed schema; modify only files that fail it.

### Task 1: Add the closed immutable Frontmatter value

**Required skills:** @superpowers-ruby:test-driven-development, @superpowers-ruby:ruby, @superpowers-ruby:ruby-commit-message

**Files:**
- Create: `lib/writing/frontmatter.rb`
- Create: `test/lib/writing/frontmatter_test.rb`

- [ ] **Step 1: Write the failing happy-path and ownership tests**

Create `test/lib/writing/frontmatter_test.rb`. Use mutable `String` instances and a mutable topics array to prove both Literal construction paths own their inputs:

```ruby
# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/writing/frontmatter")

class Writing::FrontmatterTest < ActiveSupport::TestCase
  SOURCE_PATH = "app/content/pages/writing/posts/2024-03-10-example.markerb"

  test "converts the closed Sitepress record into an immutable value" do
    title = +"Example"
    emoji = +"🦄"
    data = Sitepress::Data.manage(
      "title" => title,
      "topic" => [+"Ruby", +"Phlex"],
      "emoji" => emoji
    )

    frontmatter = Writing::Frontmatter.from(data, source_path: SOURCE_PATH)
    equal_frontmatter = Writing::Frontmatter.from(data, source_path: SOURCE_PATH)
    original_hash = frontmatter.hash

    title << " changed"
    emoji << " changed"

    assert_equal "Example", frontmatter.title
    assert_equal ["Ruby", "Phlex"], frontmatter.topics.map(&:label)
    assert_equal "🦄", frontmatter.emoji
    assert_equal equal_frontmatter, frontmatter
    assert_equal original_hash, frontmatter.hash
    assert_predicate frontmatter, :frozen?
    assert_predicate frontmatter.title, :frozen?
    assert_predicate frontmatter.topics, :frozen?
    assert frontmatter.topics.all?(&:frozen?)
    assert_predicate frontmatter.emoji, :frozen?
  end

  test "new and from_props apply every immutable property seal" do
    topics = [Writing::Topic.new(label: "Ruby")]
    title = +"Example"
    emoji = +"🦄"
    frontmatter = Writing::Frontmatter.from_props(title:, topics:, emoji:)

    title << " changed"
    topics.clear
    emoji << " changed"

    assert_equal "Example", frontmatter.title
    assert_equal ["Ruby"], frontmatter.topics.map(&:label)
    assert_equal "🦄", frontmatter.emoji
    refute_same title, frontmatter.title
    refute_same topics, frontmatter.topics
    refute_same emoji, frontmatter.emoji
  end

  test "new and from_props enforce semantic property constraints" do
    topic = Writing::Topic.new(label: "Ruby")

    assert_raises(Literal::TypeError) do
      Writing::Frontmatter.new(title: " ", topics: [topic])
    end
    assert_raises(Literal::TypeError) do
      Writing::Frontmatter.from_props(title: "Example", topics: [], emoji: nil)
    end
    assert_raises(Literal::TypeError) do
      Writing::Frontmatter.new(title: 1, topics: [topic])
    end
    assert_raises(Literal::TypeError) do
      Writing::Frontmatter.from_props(title: "Example", topics: nil, emoji: nil)
    end
    assert_raises(Literal::TypeError) do
      Writing::Frontmatter.from_props(title: "Example", topics: ["Ruby"], emoji: nil)
    end
  end
end
```

Also cover omitted `emoji`, which must read as `nil` rather than `Literal::Undefined`.

- [ ] **Step 2: Write the failing closed-schema and deterministic-error tests**

Add table-driven cases for:

- sorted unknown keys, including `date`, `topics`, `status`, `published`, and `publish_at`;
- missing `title` before missing `topic`;
- non-string, blank, and surrounding-whitespace title;
- scalar, empty, non-string, blank, padded, slugless, and duplicate topics;
- non-string, blank, and surrounding-whitespace emoji;
- a valid title plus invalid topic plus invalid emoji, proving topic wins;
- physical source path in every message;
- `Writing::Topic::Invalid` and `Literal::TypeError` retained as causes when applicable.

Use exact messages with this shape:

```text
Invalid writing frontmatter in ".../example.markerb": topic[1] must be a string
```

- [ ] **Step 3: Run the focused test and verify RED**

```bash
PARALLEL_WORKERS=1 bin/rails test test/lib/writing/frontmatter_test.rb
```

Expected: ERROR because `Writing::Frontmatter` is undefined.

- [ ] **Step 4: Implement Frontmatter with explicit factory validation and Literal seals**

Create `lib/writing/frontmatter.rb` with this public shape:

```ruby
# frozen_string_literal: true

module Writing
  class Frontmatter < Literal::Data
    class Invalid < StandardError; end

    KEYS = %w[emoji title topic].freeze

    NONBLANK_STRING = _Intersection(
      String,
      _Predicate("nonblank String without surrounding whitespace") do |value|
        value.is_a?(String) && !value.empty? && value == value.strip
      end
    )
    TOPICS = _Intersection(
      _Array(Writing::Topic),
      _Predicate("non-empty topics with case-insensitively unique labels") do |topics|
        topics.is_a?(Array) &&
          topics.any? &&
          topics.all? { _1.is_a?(Writing::Topic) } &&
          topics.map { _1.label.downcase }.uniq.length == topics.length
      end
    )

    prop :title, NONBLANK_STRING, &Immutable
    prop :topics, TOPICS, &Immutable
    prop :emoji, _Nilable(NONBLANK_STRING), default: nil, &Immutable

    def self.from(data, source_path:)
      # Validate in the specified order, then construct Topics once and call
      # new(title:, topics:, emoji:). Do not mutate, trim, split, or downcase
      # Sitepress-owned values.
    end

    class << self
      private

      def invalid!(source_path, reason, cause: nil)
        error = Invalid.new("Invalid writing frontmatter in #{source_path.inspect}: #{reason}")
        cause ? raise(error, cause: cause) : raise(error)
      end
    end
  end
end
```

The factory must check unknown and missing keys itself, validate title before
calling `Writing::Topic.from`, translate the stable Topic diagnostic into the
Frontmatter diagnostic, then validate optional emoji. Rescue only expected
domain/type failures; do not relabel arbitrary internal exceptions. Literal
seals apply to `.new` and `.from_props`, but `.from_props` skips initializers and
`after_initialize`, so place both representation ownership and semantic
invariants in the property declarations. The factory still performs ordered
checks first so authored content receives precise domain diagnostics; public
Sitepress ingestion stays on `.from`.

- [ ] **Step 5: Run focused tests and lint**

```bash
PARALLEL_WORKERS=1 bin/rails test test/lib/writing/frontmatter_test.rb
bundle exec standardrb lib/writing/frontmatter.rb test/lib/writing/frontmatter_test.rb
git diff --check
```

Expected: all Frontmatter tests pass; Standard and diff checks are silent.

- [ ] **Step 6: Commit the Frontmatter boundary**

```bash
git add lib/writing/frontmatter.rb test/lib/writing/frontmatter_test.rb
git commit -m "feat(writing): Add typed frontmatter boundary"
```

### Task 2: Add the immutable Article projection

**Required skills:** @superpowers-ruby:test-driven-development, @superpowers-ruby:ruby, @superpowers-ruby:ruby-commit-message

**Files:**
- Create: `lib/writing/article.rb`
- Create: `test/lib/writing/article_test.rb`
- Modify: `lib/writing/path.rb:8-31`
- Modify: `test/lib/writing/path_test.rb`

- [ ] **Step 1: Write failing Path ownership tests**

Add a test that constructs a Path from a mutable source string, mutates the
caller string, and verifies stable `source_path`, `slug`, `request_path`, and
publication date. Assert the Path, source path, and slug are frozen and identity
separate from the caller input. Repeat the essential assertion for a draft.

- [ ] **Step 2: Run Path tests and verify RED**

```bash
PARALLEL_WORKERS=1 bin/rails test test/lib/writing/path_test.rb
```

Expected: ownership/freezing assertions fail because Path currently retains the
source string and never freezes itself.

- [ ] **Step 3: Own Path strings and freeze successful instances**

At the beginning of `Writing::Path#initialize`, store a duplicated frozen
string rather than `source_path.to_s` directly. After successful parsing,
duplicate/freeze the parsed slug and freeze the Path. Do not freeze a caller's
object, change parsing rules, or change error messages.

- [ ] **Step 4: Run Path tests and verify GREEN**

Run the command from Step 2. Expected: all Path tests pass.

- [ ] **Step 5: Write failing Article facade tests**

Create `test/lib/writing/article_test.rb` covering:

```ruby
require "test_helper"
require Rails.root.join("lib/writing/frontmatter")
require Rails.root.join("lib/writing/article")
```

Require these files in dependency order because the application initializer
does not load them until Task 3. Then cover:

- `Article.from(resource)` exposes title, Topic values, emoji, publication date,
  draft/post state, slug, physical source path, canonical request path, and URL;
- request path and URL remain stable after the Sitepress resource is moved;
- the Article is frozen and uses identity equality/hash;
- `path`, `frontmatter`, `data`, `resource`, and generic delegation are not
  public;
- mutating the original Sitepress data after construction cannot change the
  Article;
- the resource is collectible after local references are removed (or, more
  simply, no Article instance variable contains the resource);
- invalid Path and Frontmatter errors prevent construction and retain their
  original types.

- [ ] **Step 6: Run Article tests and verify RED**

```bash
PARALLEL_WORKERS=1 bin/rails test test/lib/writing/article_test.rb
```

Expected: ERROR because `Writing::Article` is undefined.

- [ ] **Step 7: Implement the narrow frozen Article object**

Create `lib/writing/article.rb`:

```ruby
# frozen_string_literal: true

module Writing
  class Article < Literal::Object
    prop :path, Writing::Path, reader: :private
    prop :frontmatter, Writing::Frontmatter, reader: :private

    def self.from(resource)
      path = Writing::Path.new(resource.source.path)
      frontmatter = Writing::Frontmatter.from(resource.data, source_path: path.source_path)
      new(path:, frontmatter:)
    end

    def title = frontmatter.title
    def topics = frontmatter.topics
    def emoji = frontmatter.emoji
    def publication_date = path.publication_date
    def draft? = path.draft?
    def post? = path.post?
    def slug = path.slug
    def source_path = path.source_path
    def request_path = path.request_path
    def url = request_path

    private

    def after_initialize = freeze
  end
end
```

Keep constructor property readers private and do not add `method_missing`, a
resource field, a `data` method, or structural equality.

- [ ] **Step 8: Run focused tests, lint, and commit**

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/lib/writing/path_test.rb \
  test/lib/writing/article_test.rb
bundle exec standardrb \
  lib/writing/path.rb lib/writing/article.rb \
  test/lib/writing/path_test.rb test/lib/writing/article_test.rb
git diff --check
git add lib/writing/path.rb lib/writing/article.rb \
  test/lib/writing/path_test.rb test/lib/writing/article_test.rb
git commit -m "feat(writing): Add immutable article projection"
```

Expected: focused tests pass and checks are silent before committing.

### Task 3: Preflight typed Articles before pipeline mutation

**Required skills:** @superpowers-ruby:test-driven-development, @superpowers-ruby:ruby, @superpowers-ruby:ruby-commit-message

**Files:**
- Modify: `config/initializers/sitepress_writing.rb:3-7`
- Modify: `lib/writing/resource_pipeline.rb`
- Modify: `test/lib/writing/resource_pipeline_test.rb`
- Modify: `test/integration/writing_boot_validation_test.rb`

- [ ] **Step 1: Update ordinary pipeline fixtures and write failing Entry tests**

Change default writing fixture data to include both required fields:

```ruby
{"title" => "Example", "topic" => ["Ruby"]}
```

Replace Entry tests for separate `path` and `topics` with tests for:

```ruby
prop :resource, Sitepress::Resource
prop :article, Writing::Article
prop :target, _Nilable(Target)
```

Assert type rejection, structural Entry behavior with the same Article object,
and that the Entry does not duplicate path/topic state.

- [ ] **Step 2: Add failing pipeline frontmatter preflight tests**

Replace the narrow legacy/topic cases with table-driven Frontmatter cases for
every environment. For each case, capture `tree_snapshot(root)`, run the
pipeline, and assert:

- `Writing::ResourcePipeline::Invalid` includes the exact Frontmatter message;
- its cause is `Writing::Frontmatter::Invalid`;
- no draft was removed or replaced;
- no post was remapped or amended;
- no topic page was generated;
- the complete tree snapshot is unchanged.

Retain existing Path errors as `Writing::Path::Invalid`. Preserve slug, topic
registry, template, target, and collision coverage.

- [ ] **Step 3: Run pipeline tests and verify RED**

```bash
PARALLEL_WORKERS=1 bin/rails test test/lib/writing/resource_pipeline_test.rb
```

Expected: failures because entries still store Path/Topic fields and title or
unknown-key validation does not exist.

- [ ] **Step 4: Load and construct Articles during complete preflight**

Require files in this order from `config/initializers/sitepress_writing.rb`:

```ruby
require Rails.root.join("lib/writing/path").to_s
require Rails.root.join("lib/writing/topic").to_s
require Rails.root.join("lib/writing/frontmatter").to_s
require Rails.root.join("lib/writing/article").to_s
require Rails.root.join("lib/writing/topic_page").to_s
require Rails.root.join("lib/writing/resource_pipeline").to_s
```

In the pipeline, construct `Article.from(resource)` for every discovered
resource before validation that can mutate the tree. Translate only
`Frontmatter::Invalid` into `ResourcePipeline::Invalid` with `cause:`. Replace
all Entry path/topic reads with the explicit Article facade:

```ruby
article.source_path
article.slug
article.request_path
article.publication_date
article.draft?
article.post?
article.topics
```

Delete `LEGACY_KEYS`, `validate_legacy_metadata!`, and `topics_from`; the closed
schema subsumes them. Keep the current `resource.data["publish_at"]` assignment
temporarily in `apply` so the application stays working until all consumers are
cut over atomically in Task 5.

- [ ] **Step 5: Add subprocess boot coverage for the closed schema**

Extend `writing_boot_validation_test.rb` with malformed title, missing key, and
unknown-key fixtures. Assert runner code never executes and diagnostics include
the physical path. Keep the pipeline-registration assertion.

- [ ] **Step 6: Run focused pipeline and boot tests**

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/lib/writing/resource_pipeline_test.rb \
  test/integration/writing_boot_validation_test.rb \
  test/integration/writing_resource_mapping_test.rb \
  test/integration/writing_topic_archives_test.rb
```

Expected: all selected tests pass with zero failures and errors.

- [ ] **Step 7: Lint and commit the pipeline preflight**

```bash
bundle exec standardrb \
  config/initializers/sitepress_writing.rb \
  lib/writing/resource_pipeline.rb \
  test/lib/writing/resource_pipeline_test.rb \
  test/integration/writing_boot_validation_test.rb
git diff --check
git add config/initializers/sitepress_writing.rb \
  lib/writing/resource_pipeline.rb \
  test/lib/writing/resource_pipeline_test.rb \
  test/integration/writing_boot_validation_test.rb
git commit -m "refactor(writing): Preflight typed articles"
```

### Task 4: Move publication decisions onto Articles

**Required skills:** @superpowers-ruby:test-driven-development, @superpowers-ruby:ruby, @superpowers-ruby:ruby-commit-message

**Files:**
- Modify: `app/models/writing/publication_policy.rb`
- Modify: `test/models/writing/publication_policy_test.rb`

- [ ] **Step 1: Convert policy tests from Path fixtures to Article fixtures**

Build Articles from immutable Path and Frontmatter values. Retain all current
Brussels-date boundary, production accessibility, preview, and draft tests.
Add a simple interface double only if needed to prove Policy asks solely for
`post?`, `draft?`, and `publication_date`.

- [ ] **Step 2: Run policy tests and verify the interface change**

```bash
PARALLEL_WORKERS=1 bin/rails test test/models/writing/publication_policy_test.rb
```

The tests may already pass because Path and Article share the explicit query
methods; treat that as characterization, not permission to retain Path callers.

- [ ] **Step 3: Rename implementation parameters and remove Path assumptions**

Use `article` consistently in `published?` and `accessible?`. Keep the clock's
one-date-snapshot behavior and all environment rules unchanged.

- [ ] **Step 4: Run tests, lint, and commit**

```bash
PARALLEL_WORKERS=1 bin/rails test test/models/writing/publication_policy_test.rb
bundle exec standardrb \
  app/models/writing/publication_policy.rb \
  test/models/writing/publication_policy_test.rb
git diff --check
git add app/models/writing/publication_policy.rb \
  test/models/writing/publication_policy_test.rb
git commit -m "refactor(writing): Publish typed articles"
```

### Task 5: Cut catalogue and presentation over to the Article facade

**Required skills:** @superpowers-ruby:test-driven-development, @superpowers-ruby:ruby, @superpowers-ruby:ruby-commit-message

**Files:**
- Modify: `app/models/writing/catalogue.rb`
- Modify: `test/models/writing/catalogue_test.rb`
- Modify: `app/controllers/sitepress/site_controller.rb`
- Modify: `app/views/components/collection_component.rb`
- Modify: `test/components/collection_component_test.rb`
- Modify: `app/views/layouts/application_layout.rb`
- Modify: `test/views/layouts/application_layout_test.rb`
- Modify: `app/views/feed/index.xml.builder`
- Modify: `test/integration/feed_controller_test.rb`
- Modify: `test/integration/feed_publication_test.rb`
- Modify: `test/integration/writing_collection_test.rb`
- Modify: `test/integration/writing_latest_list_test.rb`
- Modify: `test/integration/writing_publication_access_test.rb`
- Modify: `test/integration/writing_topic_archives_test.rb`
- Modify: `test/integration/article_layout_test.rb`
- Modify: `lib/writing/resource_pipeline.rb`
- Modify: `test/lib/writing/resource_pipeline_test.rb`

- [ ] **Step 1: Rewrite Catalogue tests around returned Articles**

Delete private `Catalogue::Entry` tests. Update resource helpers so every
writing resource has valid title/topic frontmatter. Assert `#published` returns
Articles, not resources, and preserve:

- due-only selection and descending physical publication date;
- canonical exclusions through `article.request_path`, regardless of mutable
  resource remapping;
- exact typed-topic filtering;
- generated topic/unrelated-resource exclusion through Path failure;
- fatal Frontmatter errors for recognized writing paths;
- one clock snapshot for the whole result.

- [ ] **Step 2: Rewrite component tests around direct Article fixtures**

Replace the `Data.define(:request_path, :data)` resource fake with an Article
helper built from `Writing::Path` and `Writing::Frontmatter`. Delete blank-title
fallback and missing-topic tests because invalid values cannot cross the new
boundary; those cases belong to Frontmatter tests. Preserve empty states,
feature/row limits, linked topics, dates, aria labels, and cover dimensions.

- [ ] **Step 3: Add failing end-to-end boundary assertions**

Update feed and writing integration tests to expect unchanged HTML/XML while
using physical source paths for publication. Remove all test writes to or
assertions about `resource.data["publish_at"]`. Add assertions that catalogue
results are Articles and that scheduled access changes when the injected clock
crosses midnight without rebuilding Sitepress. Update the layout unit tests to
pass `publication_date:` and assert the same rendered date and facts markup.

- [ ] **Step 4: Run the affected tests and verify RED**

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/models/writing/catalogue_test.rb \
  test/components/collection_component_test.rb \
  test/integration/feed_controller_test.rb \
  test/integration/feed_publication_test.rb \
  test/integration/writing_collection_test.rb \
  test/integration/writing_latest_list_test.rb \
  test/integration/writing_publication_access_test.rb \
  test/integration/writing_topic_archives_test.rb \
  test/integration/article_layout_test.rb \
  test/views/layouts/application_layout_test.rb
```

Expected: failures from resource-returning Catalogue and presentation reads of
`data`/`publish_at`.

- [ ] **Step 5: Make Catalogue project and return Articles**

Remove `Writing::Catalogue::Entry`. Its internal collection should be:

```ruby
def articles
  resources.filter_map do |resource|
    Writing::Article.from(resource)
  rescue Writing::Path::Invalid
    nil
  end
end
```

Do not rescue `Writing::Frontmatter::Invalid`. Filter, exclude, sort, and map
Articles directly; `#published` returns the resulting Article array.

- [ ] **Step 6: Make the Sitepress controller distinguish Article from generic page behavior**

Replace `writing_path`/`writing_post?` with a helper that calls
`Writing::Article.from(resource)` and rescues only `Writing::Path::Invalid`.
Use an Article for publication access, writing page title, topics, publication
date, cover lookup, and the collection tail. Keep `page.data` only for generic
Sitepress layout selection, non-writing title fallback, and generated topic-page
metadata. Do not rescue invalid writing frontmatter or expose Article internals.

- [ ] **Step 7: Render only Article readers in components and feed**

In `CollectionComponent`, rename resource-oriented helpers and use:

```ruby
article.title
article.topics
article.publication_date
article.request_path
post_cover(article)
```

Delete `resource_topics`, `resource_source_path`, and title fallback. In the RSS
builder, use `post.title`, `post.publication_date`, and `post.url`. The existing
`Writing::Cover.find`/`PostCoverHelper` request-path interface needs no change.

Rename `ApplicationLayout#page_metadata`'s `publish_at:` keyword and internal
hash key to `publication_date:`. Rename `formatted_publish_date` accordingly and
use the new key in both header metadata and the facts rail. The controller must
pass `article.publication_date`; no writing presentation state should retain the
old derived-data name.

- [ ] **Step 8: Remove the pipeline's derived data mutation**

Delete:

```ruby
entry.resource.data["publish_at"] = entry.article.publication_date
```

Update pipeline assertions to use the Entry Article or physical Path facts and
to assert original resource frontmatter is unchanged after successful mapping.

- [ ] **Step 9: Run the complete affected test set until GREEN**

Run the command from Step 4 plus:

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/lib/writing/resource_pipeline_test.rb \
  test/models/writing/publication_policy_test.rb \
  test/controllers/feed_controller_test.rb \
  test/integration/writing_resource_mapping_test.rb
```

Expected: all selected tests pass; public HTML/XML and publication behavior are
unchanged.

- [ ] **Step 10: Check the boundary, lint, and commit atomically**

```bash
grep -RInE 'resource\.data|post\.data' \
  app/models/writing/catalogue.rb \
  app/views/components/collection_component.rb \
  app/views/feed/index.xml.builder \
  lib/writing/resource_pipeline.rb || true
grep -RIn 'publish_at' \
  app/views/layouts/application_layout.rb \
  app/controllers/sitepress/site_controller.rb \
  app/views/feed/index.xml.builder \
  app/views/components/collection_component.rb \
  lib/writing/resource_pipeline.rb || true
bundle exec standardrb \
  app/models/writing/catalogue.rb \
  app/models/writing/publication_policy.rb \
  app/controllers/sitepress/site_controller.rb \
  app/views/components/collection_component.rb \
  app/views/layouts/application_layout.rb \
  lib/writing/resource_pipeline.rb \
  test/models/writing/catalogue_test.rb \
  test/components/collection_component_test.rb \
  test/views/layouts/application_layout_test.rb
git diff --check
```

Expected: grep prints no matches in the listed writing consumers, Standard is
clean, and diff check is silent.

Commit all Task 5 implementation and affected tests together so no completed
commit leaves Catalogue returning a type its consumers cannot render:

```bash
git add app/models/writing/catalogue.rb \
  app/controllers/sitepress/site_controller.rb \
  app/views/components/collection_component.rb \
  app/views/layouts/application_layout.rb \
  app/views/feed/index.xml.builder \
  lib/writing/resource_pipeline.rb \
  test/models/writing/catalogue_test.rb \
  test/components/collection_component_test.rb \
  test/views/layouts/application_layout_test.rb \
  test/lib/writing/resource_pipeline_test.rb \
  test/controllers/feed_controller_test.rb \
  test/integration/feed_controller_test.rb \
  test/integration/feed_publication_test.rb \
  test/integration/writing_collection_test.rb \
  test/integration/writing_latest_list_test.rb \
  test/integration/writing_publication_access_test.rb \
  test/integration/writing_resource_mapping_test.rb \
  test/integration/writing_topic_archives_test.rb \
  test/integration/article_layout_test.rb
git commit -m "refactor(writing): Use articles across presentation"
```

### Task 6: Make draft scaffolding satisfy the title contract

**Required skills:** @superpowers-ruby:test-driven-development, @superpowers-ruby:ruby-commit-message

**Files:**
- Modify: `go:34-65,122-160`
- Modify: `test/scripts/go_write_test.sh`
- Verify: `app/content/templates/writing.makerb`
- Verify/modify if required: `app/content/pages/writing/drafts/*`
- Verify/modify if required: `app/content/pages/writing/posts/*`

- [ ] **Step 1: Add failing trimmed-title shell tests**

Add cases proving:

- `"  My New Post  "` writes title `"My New Post"` and slug
  `my-new-post.markerb`;
- an all-whitespace title fails before the topic prompt and creates no file;
- YAML-significant trimmed titles remain quoted and parse to the exact trimmed
  value;
- punctuation-only titles retain the existing ASCII-slug diagnostic;
- existing topic, collision, atomic cleanup, signal, and permissions cases stay
  unchanged.

- [ ] **Step 2: Run the shell suite and verify RED**

```bash
bash test/scripts/go_write_test.sh
```

Expected: trimmed-title cases fail because `go write` currently slugs and writes
the raw title.

- [ ] **Step 3: Trim once before validation, slugging, and serialization**

After reading the title, derive a separate trimmed value without evaluating it
as shell code. Reject an empty trimmed title before prompting for topics. Pass
the trimmed value to the existing Ruby slug command and JSON/YAML-safe template
substitution. Keep collision detection, temporary-file cleanup, permissions,
and no-overwrite behavior unchanged.

Use the existing argv-safe Ruby pattern:

```bash
if title=$(ruby -e 'print ARGV.fetch(0).strip' "$input"); then
  :
else
  echo "Failed to normalize title" >&2
  return 1
fi

if [[ -z "$title" ]]; then
  echo "Title must not be blank" >&2
  return 1
fi
```

- [ ] **Step 4: Run shell and boot/content checks**

```bash
bash test/scripts/go_write_test.sh
bin/rails runner 'puts Sitepress.site.resources.count'
```

Expected: shell suite passes and Rails boots while loading every current writing
resource. If the runner reveals a real closed-schema content violation, repair
only that frontmatter and rerun both commands.

- [ ] **Step 5: Lint and commit**

```bash
bash -n go
bash -n test/scripts/go_write_test.sh
git diff --check
git add go test/scripts/go_write_test.sh
git add app/content/pages/writing/drafts app/content/pages/writing/posts
git commit -m "fix(writing): Scaffold valid article titles"
```

Do not stage content paths if no content file changed. Expected: checks pass and
the commit contains only scaffold tests/implementation plus necessary schema
repairs, if any.

### Task 7: Verify the complete typed writing boundary

**Required skills:** @superpowers-ruby:verification-before-completion, @superpowers-ruby:requesting-code-review

**Files:**
- Verify all implementation and test files from Tasks 1-6.
- Verify `Gemfile.lock` still resolves the pinned Literal revision.

- [ ] **Step 1: Run the complete test matrix**

```bash
bash test/scripts/go_write_test.sh
bin/rails test
```

Expected: shell suite and all Rails tests pass with zero failures and errors.

- [ ] **Step 2: Run complete style and boot checks**

```bash
bundle exec standardrb
bin/rails runner 'puts "booted with Literal #{Literal::VERSION}: #{Sitepress.site.resources.count} resources"'
bundle check
bundle info literal
```

Expected: Standard is silent; Rails reports Literal 1.9.0 and a resource count;
Bundler is complete; Literal resolves from `e51ef7c`.

- [ ] **Step 3: Audit the writing boundary and diff**

```bash
grep -RInE 'resource\.data|page\.data|post\.data' \
  app/controllers app/views app/models/writing lib/writing || true
grep -RIn 'publish_at' app/controllers app/views app/models/writing lib/writing || true
git diff --check main...HEAD
git status --short
```

Expected: remaining controller data reads are demonstrably generic Sitepress or
generated-topic-page behavior; no writing title/topic/emoji/publication-date
consumer bypasses Article; no pipeline-derived `publish_at` write remains; diff
check is silent; status contains no uncommitted implementation files.

- [ ] **Step 4: Request final code review**

Dispatch one final reviewer against the approved spec, this plan, the complete
branch diff, and fresh verification output. Fix blocking findings and repeat
the relevant focused/full checks before requesting re-review.

- [ ] **Step 5: Record final verification if review changes code**

If review required changes, rerun Steps 1-3. Commit reviewed corrections with a
narrow Conventional Commit message and leave the feature branch clean.
