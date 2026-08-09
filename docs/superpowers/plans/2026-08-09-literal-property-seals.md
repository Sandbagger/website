# Literal Property Seals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace five writing value-object defensive-copy assignments with Literal property seals that protect every construction path.

**Architecture:** Pin the exact Literal main-branch revision that introduces coercion/seal pipelines, then declare the built-in shallow `Immutable` seal on the five existing string and array ownership boundaries. Drive the migration with `from_props` tests because this final-value constructor bypasses `after_initialize` but deliberately applies seals; preserve the validation-only parts of the topic and cover hooks.

**Tech Stack:** Ruby 3.3.5, Rails 8, Literal main at `e51ef7c3e6a03127977acc06071a020b497be24e`, Bundler, Minitest, Standard Ruby

---

## File map

- `Gemfile`: source Literal 1.9.0 from the exact reviewed Git revision.
- `Gemfile.lock`: record the Git remote, revision, and dependency source.
- `lib/writing/topic.rb`: seal `label`; retain only topic-label validation in the hook.
- `lib/writing/resource_pipeline.rb`: seal `Entry#topics`; remove its copy-only hook.
- `app/models/writing/catalogue.rb`: seal `Entry#topics`; remove its copy-only hook.
- `app/models/writing/cover.rb`: seal `Variant#src` and `Cover#variants`; retain only dimension validation in the cover hook.
- `test/lib/writing/topic_test.rb`: prove `from_props` cannot retain a mutable caller string.
- `test/lib/writing/resource_pipeline_test.rb`: prove `from_props` cannot retain a mutable caller topics array.
- `test/models/writing/catalogue_test.rb`: prove the same catalogue-entry ownership contract.
- `test/models/writing/cover_test.rb`: prove `from_props` seals both variant sources and the cover variants array.

### Task 1: Pin Literal's property-seal revision

**Files:**
- Modify: `Gemfile:9`
- Modify: `Gemfile.lock`

- [ ] **Step 1: Change the Literal dependency to the reviewed revision**

Replace the RubyGems-only declaration with:

```ruby
gem "literal", "~> 1.9.0",
  github: "yippee-fun/literal",
  ref: "e51ef7c3e6a03127977acc06071a020b497be24e"
```

- [ ] **Step 2: Resolve only Literal from the pinned Git source**

Run:

```bash
bundle update literal
```

Expected: Bundler completes successfully; `Gemfile.lock` gains a `GIT` block for
`https://github.com/yippee-fun/literal.git` at revision
`e51ef7c3e6a03127977acc06071a020b497be24e`; unrelated gem versions do not
change.

- [ ] **Step 3: Verify the new API and source**

Run:

```bash
bundle exec ruby -e 'require "literal"; abort unless Literal::VERSION == "1.9.0"; abort unless Literal::Coercions::Immutable; abort unless Literal::Data.respond_to?(:from_props); puts "Literal seals available"'
bundle info literal
bundle check
```

Expected: the Ruby probe prints `Literal seals available`; `bundle info` points
to Bundler's checkout of the pinned Git revision; `bundle check` reports that
all dependencies are satisfied.

- [ ] **Step 4: Commit the reproducible dependency change**

```bash
git add Gemfile Gemfile.lock
git commit -m "build(types): Pin Literal property seals"
```

### Task 2: Specify seal behavior on every migrated construction path

**Required skills:** @superpowers-ruby:test-driven-development, @superpowers-ruby:ruby

**Files:**
- Modify: `test/lib/writing/topic_test.rb`
- Modify: `test/lib/writing/resource_pipeline_test.rb`
- Modify: `test/models/writing/catalogue_test.rb`
- Modify: `test/models/writing/cover_test.rb`

- [ ] **Step 1: Add a failing final-value construction test for topics**

Add to `Writing::TopicTest`:

```ruby
test "from_props applies the immutable label seal" do
  label = +"Ruby"
  topic = Writing::Topic.from_props(label: label)

  label << " on Rails"

  assert_equal "Ruby", topic.label
  assert_predicate topic.label, :frozen?
  refute_same label, topic.label
end
```

- [ ] **Step 2: Add failing final-value construction tests for entry arrays**

Add to `Writing::ResourcePipelineTest`:

```ruby
test "from_props applies the immutable topics seal" do
  root = Sitepress::Node.new
  source_path = "app/content/pages/writing/posts/2024-03-10-example.markerb"
  resource = add_resource(root, source_path)
  topics = [Writing::Topic.new(label: "Ruby")]
  entry = Writing::ResourcePipeline::Entry.from_props(
    resource: resource,
    path: Writing::Path.new(source_path),
    target: nil,
    topics: topics
  )

  topics << Writing::Topic.new(label: "Phlex")

  assert_equal ["Ruby"], entry.topics.map(&:label)
  assert_predicate entry.topics, :frozen?
  refute_same topics, entry.topics
end
```

Add the analogous test to `Writing::CatalogueTest`, using its existing
`resource` helper:

```ruby
test "from_props applies the immutable topics seal" do
  sitepress_resource = resource(
    "/writing/example",
    "writing/posts/2024-03-10-example.markerb"
  )
  topics = [Writing::Topic.new(label: "Ruby")]
  entry = Writing::Catalogue::Entry.from_props(
    resource: sitepress_resource,
    path: Writing::Path.new(sitepress_resource.source.path),
    topics: topics
  )

  topics << Writing::Topic.new(label: "Phlex")

  assert_equal ["Ruby"], entry.topics.map(&:label)
  assert_predicate entry.topics, :frozen?
  refute_same topics, entry.topics
end
```

- [ ] **Step 3: Add a failing final-value construction test for cover strings and arrays**

Add to `Writing::CoverTest`:

```ruby
test "from_props applies the immutable cover seals" do
  sources = SIZES.map { |width, _height| +"/images/posts/example-#{width}w.webp" }
  variants = SIZES.map.with_index do |(width, height), index|
    Writing::Cover::Variant.from_props(
      src: sources.fetch(index),
      width: width,
      height: height
    )
  end
  cover = Writing::Cover.from_props(variants: variants)

  sources.first << "-mutated"
  variants << variants.first

  assert_equal "/images/posts/example-480w.webp", cover.variants.first.src
  assert_predicate cover.variants.first.src, :frozen?
  assert_equal SIZES.to_a, cover.variants.map { [_1.width, _1.height] }
  assert_predicate cover.variants, :frozen?
  refute_same variants, cover.variants
end
```

- [ ] **Step 4: Run the focused tests and confirm the red state**

Run:

```bash
bin/rails test \
  test/lib/writing/topic_test.rb \
  test/lib/writing/resource_pipeline_test.rb \
  test/models/writing/catalogue_test.rb \
  test/models/writing/cover_test.rb
```

Expected: the four new tests fail because `from_props` bypasses the current
`after_initialize` copies, leaving caller-owned strings and arrays shared and
mutable. Existing tests continue to pass.

### Task 3: Move ownership rules into Literal property seals

**Required skills:** @superpowers-ruby:test-driven-development, @superpowers-ruby:ruby

**Files:**
- Modify: `lib/writing/topic.rb:5-43`
- Modify: `lib/writing/resource_pipeline.rb:23-35`
- Modify: `app/models/writing/catalogue.rb:5-12`
- Modify: `app/models/writing/cover.rb:8-20,34-84`
- Test: `test/lib/writing/topic_test.rb`
- Test: `test/lib/writing/resource_pipeline_test.rb`
- Test: `test/models/writing/catalogue_test.rb`
- Test: `test/models/writing/cover_test.rb`

- [ ] **Step 1: Seal `Writing::Topic#label` and keep validation only**

Change the property declaration to:

```ruby
prop :label, String, &Immutable
```

Delete `@label = label.dup.freeze` from `after_initialize`; preserve the three
existing validation checks and their order exactly.

- [ ] **Step 2: Seal both entry topics arrays and remove copy-only hooks**

In both entry classes, change the declaration to:

```ruby
prop :topics, _Array(Writing::Topic), &Immutable
```

Delete `Writing::ResourcePipeline::Entry#after_initialize` and
`Writing::Catalogue::Entry#after_initialize` entirely.

- [ ] **Step 3: Seal cover sources and variants while preserving dimension validation**

Change the two declarations to:

```ruby
prop :src, String, &Immutable
prop :variants, _Array(Variant), &Immutable
```

Delete `Writing::Cover::Variant#after_initialize` entirely. Delete only
`@variants = variants.dup.freeze` from `Writing::Cover#after_initialize`; retain
the ordered-dimension check and its existing `Writing::Cover::Invalid` message.

- [ ] **Step 4: Run the focused tests and confirm the green state**

Run:

```bash
bin/rails test \
  test/lib/writing/topic_test.rb \
  test/lib/writing/resource_pipeline_test.rb \
  test/models/writing/catalogue_test.rb \
  test/models/writing/cover_test.rb
```

Expected: all focused tests pass, including both ordinary constructors and the
new `from_props` paths.

- [ ] **Step 5: Run focused linting**

Run:

```bash
bundle exec standardrb \
  lib/writing/topic.rb \
  lib/writing/resource_pipeline.rb \
  app/models/writing/catalogue.rb \
  app/models/writing/cover.rb \
  test/lib/writing/topic_test.rb \
  test/lib/writing/resource_pipeline_test.rb \
  test/models/writing/catalogue_test.rb \
  test/models/writing/cover_test.rb
```

Expected: no offenses.

- [ ] **Step 6: Commit the tested seal migration**

```bash
git add \
  lib/writing/topic.rb \
  lib/writing/resource_pipeline.rb \
  app/models/writing/catalogue.rb \
  app/models/writing/cover.rb \
  test/lib/writing/topic_test.rb \
  test/lib/writing/resource_pipeline_test.rb \
  test/models/writing/catalogue_test.rb \
  test/models/writing/cover_test.rb
git commit -m "refactor(types): Seal writing value properties"
```

### Task 4: Verify the complete application and dependency boundary

**Required skill:** @superpowers-ruby:verification-before-completion

**Files:**
- Verify: `Gemfile`
- Verify: `Gemfile.lock`
- Verify: all production and test files changed above

- [ ] **Step 1: Run the complete Minitest suite**

Run:

```bash
bin/rails test
```

Expected: all tests pass with zero failures and zero errors.

- [ ] **Step 2: Run the complete Ruby style check**

Run:

```bash
bundle exec standardrb
```

Expected: no offenses.

- [ ] **Step 3: Verify application boot and dependency integrity**

Run:

```bash
bin/rails runner 'puts "booted with Literal #{Literal::VERSION}"'
bundle check
bundle info literal
```

Expected: Rails prints `booted with Literal 1.9.0`; Bundler reports a complete
bundle; Literal resolves from the pinned Git checkout.

- [ ] **Step 4: Verify the migration is complete and the diff is clean**

Run:

```bash
rg -n '@(label|topics|src|variants) = .*dup\.freeze' \
  lib/writing/topic.rb \
  lib/writing/resource_pipeline.rb \
  app/models/writing/catalogue.rb \
  app/models/writing/cover.rb
git diff --check HEAD~2..HEAD
git status --short
```

Expected: `rg` finds no migrated defensive-copy assignment; the diff check is
silent; status contains no uncommitted implementation files.
