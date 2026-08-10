# Literal Target Deep Immutability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `Writing::ResourcePipeline::Target#node_names` own a deeply frozen value graph whose content, equality, and hash cannot change through caller mutation.

**Architecture:** Keep the existing plain `_Array(String)` property and apply Literal's built-in `DeepImmutable` seal at that boundary. Drive the one-line production change with ordinary-constructor and `from_props` ownership tests that mutate the caller's array and strings while preserving existing type-error behavior for shareable invalid inputs.

**Tech Stack:** Ruby 3.3.5, Rails 8, Literal 1.9.0 pinned at `e51ef7c3e6a03127977acc06071a020b497be24e`, Minitest, Standard Ruby

---

## File map

- `lib/writing/resource_pipeline.rb`: add the built-in deep-immutability seal to `Target#node_names`.
- `test/lib/writing/resource_pipeline_test.rb`: specify caller ownership, frozen nested values, stable equality/hash, and both Literal construction paths.

### Task 1: Deeply own pipeline target node names

**Required skills:** @superpowers-ruby:test-driven-development, @superpowers-ruby:ruby, @superpowers-ruby:ruby-commit-message

**Files:**
- Modify: `lib/writing/resource_pipeline.rb:10-16`
- Modify: `test/lib/writing/resource_pipeline_test.rb:130-160`

- [ ] **Step 1: Add a failing ordinary-construction ownership test**

Add next to the existing target value-object tests:

```ruby
test "target deeply owns its node names" do
  node_names = [+"writing", +"example"]
  caller_name = node_names.first
  target = Writing::ResourcePipeline::Target.new(node_names: node_names, format: :html)
  equal_target = Writing::ResourcePipeline::Target.new(
    node_names: ["writing", "example"],
    format: :html
  )
  original_hash = target.hash

  caller_name << "-mutated"
  node_names << +"extra"

  assert_equal ["writing", "example"], target.node_names
  assert_equal equal_target, target
  assert_equal original_hash, target.hash
  assert_predicate target.node_names, :frozen?
  assert target.node_names.all?(&:frozen?)
  refute_same node_names, target.node_names
  refute_same caller_name, target.node_names.first
  refute_predicate node_names, :frozen?
  refute_predicate caller_name, :frozen?
end
```

- [ ] **Step 2: Add a failing `from_props` ownership test**

Add:

```ruby
test "target from_props deeply owns its node names" do
  node_names = [+"writing", +"example"]
  caller_name = node_names.first
  target = Writing::ResourcePipeline::Target.from_props(
    node_names: node_names,
    format: :html
  )
  equal_target = Writing::ResourcePipeline::Target.new(
    node_names: ["writing", "example"],
    format: :html
  )
  original_hash = target.hash

  caller_name.replace("changed")
  node_names.clear

  assert_equal ["writing", "example"], target.node_names
  assert_equal equal_target, target
  assert_equal original_hash, target.hash
  assert_predicate target.node_names, :frozen?
  assert target.node_names.all?(&:frozen?)
  refute_same node_names, target.node_names
  refute_same caller_name, target.node_names.first
  refute_predicate node_names, :frozen?
  refute_predicate caller_name, :frozen?
end
```

- [ ] **Step 3: Run the focused test and verify the red state**

Run:

```bash
bin/rails test test/lib/writing/resource_pipeline_test.rb
```

Expected: the two new tests fail because both construction paths retain the
caller-owned array and strings. Existing resource-pipeline tests, including the
integer-member `Literal::TypeError` test, continue to pass.

- [ ] **Step 4: Add the minimal property seal**

Change only the target property declaration:

```ruby
prop :node_names, _Array(String), &DeepImmutable
```

Do not add prevalidation, coercion, a custom seal, or error translation.
Invalid unshareable graphs may fail during the seal before Literal's declared
type check, as documented in the design.

- [ ] **Step 5: Run the focused test and verify the green state**

Run:

```bash
bin/rails test test/lib/writing/resource_pipeline_test.rb
```

Expected: all resource-pipeline tests pass with zero failures and zero errors.

- [ ] **Step 6: Run focused linting and diff validation**

Run:

```bash
bundle exec standardrb \
  lib/writing/resource_pipeline.rb \
  test/lib/writing/resource_pipeline_test.rb
git diff --check
```

Expected: Standard reports no offenses and the diff check is silent.

- [ ] **Step 7: Commit the tested change**

```bash
git add lib/writing/resource_pipeline.rb test/lib/writing/resource_pipeline_test.rb
git commit -m "fix(types): Deep-freeze target node names"
```

### Task 2: Verify the complete application and dependency boundary

**Required skill:** @superpowers-ruby:verification-before-completion

**Files:**
- Verify: `lib/writing/resource_pipeline.rb`
- Verify: `test/lib/writing/resource_pipeline_test.rb`
- Verify: `Gemfile.lock`

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
bundle; Literal resolves from the pinned `e51ef7c` Git checkout.

- [ ] **Step 4: Verify the exact change and clean state**

Run:

```bash
grep -n 'prop :node_names, _Array(String), &DeepImmutable' lib/writing/resource_pipeline.rb
git diff --check HEAD~1..HEAD
git status --short
```

Expected: grep prints exactly one matching declaration; diff check is silent;
status contains no uncommitted implementation files.
