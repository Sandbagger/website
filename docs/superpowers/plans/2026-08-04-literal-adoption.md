# Literal Adoption Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install Literal 1.9 and use `Literal::Data` for the application's three existing immutable production value objects.

**Architecture:** Keep the value objects nested in their current owning classes so constant names and Rails loading remain unchanged. Replace only Ruby `Data` declarations with explicitly typed `Literal::Data` classes, preserving the required `target:` keyword for pipeline entries with a small delegating initializer.

**Tech Stack:** Ruby 3.3.5, Rails 8.0, Bundler, Literal 1.9, Minitest, Standard Ruby

---

## File map

- Modify `Gemfile` and `Gemfile.lock` to add and lock the runtime dependency.
- Modify `app/models/writing/catalogue.rb` to type `Catalogue::Entry`.
- Modify `test/models/writing/catalogue_test.rb` to cover the entry contract.
- Modify `lib/writing/resource_pipeline.rb` to type `Target` and `Entry`.
- Modify `test/lib/writing/resource_pipeline_test.rb` to cover both contracts.

### Task 1: Add the Literal runtime dependency

**Files:**
- Modify: `Gemfile`
- Modify: `Gemfile.lock`

- [ ] **Step 1: Add the dependency declaration**

Add this alongside the other ungrouped runtime dependencies in `Gemfile`:

```ruby
gem "literal", "~> 1.9.0"
```

- [ ] **Step 2: Resolve the lockfile**

Run: `bundle install`

Expected: Bundler resolves a Literal 1.9.x release, updates `Gemfile.lock`, and exits successfully.

- [ ] **Step 3: Verify Literal loads**

Run: `bundle exec ruby -e 'require "literal"; puts Literal::VERSION'`

Expected: prints a version in the `1.9.x` series and exits successfully.

- [ ] **Step 4: Commit the dependency**

```bash
git add Gemfile Gemfile.lock
git commit -m "build(types): Add Literal"
```

### Task 2: Type the catalogue entry

**Files:**
- Modify: `test/models/writing/catalogue_test.rb`
- Modify: `app/models/writing/catalogue.rb`

- [ ] **Step 1: Write failing value-object tests**

Add a test that builds two `Writing::Catalogue::Entry` instances from the same
`Sitepress::Resource` and `Writing::Path`, then asserts:

```ruby
assert_equal first, second
assert first.eql?(second)
assert_equal first.hash, second.hash
assert_predicate first, :frozen?
assert_same resource, first.resource
assert_same path, first.path
```

Add invalid-property assertions:

```ruby
assert_raises(Literal::TypeError) do
  Writing::Catalogue::Entry.new(resource: Object.new, path: path)
end

assert_raises(Literal::TypeError) do
  Writing::Catalogue::Entry.new(resource: resource, path: Object.new)
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bin/rails test test/models/writing/catalogue_test.rb`

Expected: FAIL because the current Ruby `Data` entry accepts invalid property types.

- [ ] **Step 3: Implement the typed entry**

Replace the `Data.define` declaration with:

```ruby
class Entry < Literal::Data
  prop :resource, Sitepress::Resource
  prop :path, Path
end
```

- [ ] **Step 4: Run the focused tests**

Run: `bin/rails test test/models/writing/catalogue_test.rb`

Expected: all catalogue tests pass with zero failures and zero errors.

- [ ] **Step 5: Commit the catalogue conversion**

```bash
git add app/models/writing/catalogue.rb test/models/writing/catalogue_test.rb
git commit -m "refactor(writing): Type catalogue entries"
```

### Task 3: Type resource-pipeline targets

**Files:**
- Modify: `test/lib/writing/resource_pipeline_test.rb`
- Modify: `lib/writing/resource_pipeline.rb`

- [ ] **Step 1: Write failing target tests**

Add tests constructing equivalent `Writing::ResourcePipeline::Target` values
and assert keyword readers, `==`, `eql?`, matching hashes, and `frozen?`. Assert
that a non-string node name and a non-symbol format each raise
`Literal::TypeError`:

```ruby
assert_raises(Literal::TypeError) do
  Writing::ResourcePipeline::Target.new(node_names: [1], format: :html)
end

assert_raises(Literal::TypeError) do
  Writing::ResourcePipeline::Target.new(node_names: ["writing"], format: "html")
end
```

- [ ] **Step 2: Run the target tests to verify they fail**

Run: `bin/rails test test/lib/writing/resource_pipeline_test.rb`

Expected: FAIL because the current Ruby `Data` target does not enforce property types.

- [ ] **Step 3: Implement the typed target**

Replace the `Target` `Data.define` declaration with:

```ruby
class Target < Literal::Data
  prop :node_names, _Array(String)
  prop :format, Symbol

  def existing_resource(root)
    root.dig(*node_names)&.resources&.format(format)
  end

  def materialize(root)
    node_names.reduce(root) { |parent, name| parent.child(name) }
  end
end
```

- [ ] **Step 4: Run the focused tests**

Run: `bin/rails test test/lib/writing/resource_pipeline_test.rb`

Expected: all resource-pipeline tests pass with zero failures and zero errors.

- [ ] **Step 5: Commit the target conversion**

```bash
git add lib/writing/resource_pipeline.rb test/lib/writing/resource_pipeline_test.rb
git commit -m "refactor(writing): Type pipeline targets"
```

### Task 4: Type resource-pipeline entries

**Files:**
- Modify: `test/lib/writing/resource_pipeline_test.rb`
- Modify: `lib/writing/resource_pipeline.rb`

- [ ] **Step 1: Write failing entry tests**

Build a real `Sitepress::Resource`, `Writing::Path`, and target. Assert equivalent
pipeline entries have keyword readers, `==`, `eql?`, matching hashes, and are
frozen. Assert a nil target is valid when passed explicitly, omission of
`target:` raises `ArgumentError`, and invalid resource/path/target values raise
`Literal::TypeError`.

- [ ] **Step 2: Run the entry tests to verify they fail**

Run: `bin/rails test test/lib/writing/resource_pipeline_test.rb`

Expected: FAIL because the current Ruby `Data` entry does not enforce property types.

- [ ] **Step 3: Implement the typed entry**

Replace the `Entry` `Data.define` declaration with:

```ruby
class Entry < Literal::Data
  prop :resource, Sitepress::Resource
  prop :path, Path
  prop :target, _Nilable(Target)

  def initialize(resource:, path:, target:)
    super
  end
end
```

- [ ] **Step 4: Run the focused tests**

Run: `bin/rails test test/lib/writing/resource_pipeline_test.rb`

Expected: all resource-pipeline tests pass with zero failures and zero errors.

- [ ] **Step 5: Commit the entry conversion**

```bash
git add lib/writing/resource_pipeline.rb test/lib/writing/resource_pipeline_test.rb
git commit -m "refactor(writing): Type pipeline entries"
```

### Task 5: Verify the integration and catalogue future candidates

**Files:**
- Inspect all modified files and relevant Ruby object declarations.

- [ ] **Step 1: Run all tests**

Run: `bin/rails test`

Expected: complete test suite passes with zero failures and zero errors.

- [ ] **Step 2: Run style checks**

Run: `bundle exec standardrb`

Expected: exits successfully with no style violations.

- [ ] **Step 3: Verify application boot**

Run: `bin/rails runner 'puts "booted"'`

Expected: prints `booted` and exits successfully.

- [ ] **Step 4: Review the final dependency and diff**

Run: `bundle info literal && git diff HEAD~4 --check && git status --short`

Expected: Literal resolves from the bundle, the implementation diff has no
whitespace errors, and only pre-existing unrelated files remain untracked.

- [ ] **Step 5: Report further candidates without expanding this change**

Re-run:

```bash
rg -n "Data\.define|Struct\.new|attr_reader|def initialize" app lib test --glob '*.rb'
```

Classify remaining candidates by benefit and risk. In the handoff, explicitly
explain why behavioral parsers/services, Phlex components, and test doubles were
not converted in this first pass.
