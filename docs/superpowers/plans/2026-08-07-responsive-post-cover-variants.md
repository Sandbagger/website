# Responsive Post Cover Variants Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add committed 480w, 768w, and 1200w lossless WebP post-cover variants and render accurate `srcset` and context-specific `sizes` attributes through a strict immutable `Writing::Cover` contract.

**Architecture:** `Writing::Cover` remains the only discovery and validation boundary. It builds an ordered immutable collection of nested `Variant` values from three exact width-suffixed files, exposes the 1200w fallback and a deterministic `srcset`, and rejects partial, lossy, mislabeled, or unreadable sets. Article and homepage views reuse that metadata while supplying layout-specific `sizes`; responsive files are one-time committed assets with no generator or runtime image dependency.

**Tech Stack:** Ruby 3.3, Rails 8, Sitepress 5 beta4, Literal, Phlex, Minitest, FastImage, ImageMagick, WebP tools

---

## File Map

- `public/images/posts/*.webp`: retain each verified 1200-by-630 master long
  enough to generate and validate three width-suffixed candidates, then remove
  the unsuffixed compatibility files.
- `app/models/writing/cover.rb`: own variant discovery, VP8L and exact-dimension
  validation, immutability, fallback metadata, and `srcset` construction.
- `app/views/layouts/application_layout.rb`: render article-cover `srcset` and
  the article-specific `sizes` hint.
- `app/views/components/collection_component.rb`: render homepage feature
  `srcset` and the homepage-specific `sizes` hint.
- `test/models/writing/cover_assets_test.rb`: enforce responsive binary and
  repository inventory invariants.
- `test/models/writing/cover_test.rb`: specify the cover/variant contract and
  all missing or invalid-set behavior.
- `test/helpers/post_cover_helper_test.rb`: retain the helper integration check
  against the new fallback URL.
- `test/views/layouts/application_layout_test.rb`: specify article image
  attributes.
- `test/components/collection_component_test.rb`: specify homepage feature
  image attributes.
- `test/integration/article_layout_test.rb`: verify article HTTP output.
- `test/integration/writing_collection_test.rb`: verify homepage HTTP output.
- `CLAUDE.md`: document the three-file responsive-cover policy.

### Task 1: Generate and Validate Responsive Candidates

**Files:**

- Modify: `test/models/writing/cover_assets_test.rb`
- Create: `public/images/posts/*-480w.webp` (seven files)
- Create: `public/images/posts/*-768w.webp` (seven files)
- Create: `public/images/posts/*-1200w.webp` (seven files)

The unsuffixed masters remain temporarily so the existing application stays
green until Task 2 migrates the cover model. They are removed in Task 4.

- [ ] **Step 1: Add a failing responsive-variant asset test**

Keep the canonical-master test for this intermediate task, but change its
lookup so the new candidates do not enter the master inventory assertion:

```ruby
test "repository retains canonical dimensioned WebP masters during migration" do
  root = Rails.root.join("public/images/posts")
  masters = EXPECTED.map { |slug| root.join("#{slug}.webp") }

  masters.each do |path|
    image = Sitepress::Image.new(path: path)

    assert_predicate path, :file?
    assert_equal :webp, FastImage.type(path.to_s), path.to_s
    assert_equal [1200, 630], [image.width, image.height], path.to_s
  end
end
```

Then add these constants and a second test to `Writing::CoverAssetsTest`:

```ruby
SIZES = {
  480 => 252,
  768 => 403,
  1200 => 630
}.freeze

test "repository contains every responsive lossless WebP variant" do
  root = Rails.root.join("public/images/posts")
  expected = EXPECTED.product(SIZES.keys).map do |slug, width|
    "#{slug}-#{width}w.webp"
  end.sort
  variants = root.glob("*-{480,768,1200}w.webp")

  assert_equal expected, variants.map { _1.basename.to_s }.sort

  variants.each do |path|
    width = path.basename.to_s.match(/-(480|768|1200)w\.webp\z/)[1].to_i
    image = Sitepress::Image.new(path: path)

    assert_equal :webp, FastImage.type(path.to_s), path.to_s
    assert_equal "VP8L", path.binread(4, 12), path.to_s
    assert_equal [width, SIZES.fetch(width)], [image.width, image.height], path.to_s
  end
end
```

- [ ] **Step 2: Run the new test and verify RED**

Run:

```bash
PARALLEL_WORKERS=1 bin/rails test test/models/writing/cover_assets_test.rb
```

Expected: FAIL because the expected 21 width-suffixed files do not exist.

- [ ] **Step 3: Generate lossless variants without adding a permanent tool**

Run this one-time conversion from the existing verified masters:

```bash
for source in public/images/posts/*.webp; do
  stem="${source%.webp}"
  magick "$source" -resize 480x -define webp:lossless=true "${stem}-480w.webp"
  magick "$source" -resize 768x -define webp:lossless=true "${stem}-768w.webp"
  cp "$source" "${stem}-1200w.webp"
done
```

Do not add this loop to the repository. ImageMagick's proportional resize
produces 480-by-252 and 768-by-403 candidates; copying the existing master
preserves the verified 1200-by-630 bitstream.

- [ ] **Step 4: Run binary and Rails validation and verify GREEN**

Run:

```bash
PARALLEL_WORKERS=1 bin/rails test test/models/writing/cover_assets_test.rb
webpinfo public/images/posts/*-{480,768,1200}w.webp
PARALLEL_WORKERS=1 bin/rails test
```

Expected: the asset test and full suite pass. `webpinfo` reports 21 files,
each with a `VP8L` chunk, `Format: Lossless (2)`, its expected dimensions,
and `No error detected.`

- [ ] **Step 5: Commit the candidate assets**

```bash
git add test/models/writing/cover_assets_test.rb public/images/posts/*-{480,768,1200}w.webp
git commit -m "feat(images): Add responsive cover variants"
```

### Task 2: Upgrade the Strict Cover Contract

**Files:**

- Modify: `test/models/writing/cover_test.rb`
- Modify: `test/helpers/post_cover_helper_test.rb`
- Modify: `app/models/writing/cover.rb`

- [ ] **Step 1: Rewrite cover tests around the variant contract**

In `Writing::CoverTest`, add `require "fileutils"`, then define the expected
dimensions and canonical source:

```ruby
SIZES = {
  480 => 252,
  768 => 403,
  1200 => 630
}.freeze
CANONICAL_SLUG = "pettis-good-tariffs-vs-bad"
LOSSY_WEBP = "UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAUAmJaQAA3AA/vz0AAA="
```

Replace the current canonical metadata test with:

```ruby
test "find returns immutable responsive metadata for a canonical cover" do
  cover = Writing::Cover.find(resource(CANONICAL_SLUG))
  original_hash = cover.hash

  assert_instance_of Writing::Cover, cover
  assert_equal [480, 768, 1200], cover.variants.map(&:width)
  assert_equal [252, 403, 630], cover.variants.map(&:height)
  assert_equal "/images/posts/#{CANONICAL_SLUG}-1200w.webp", cover.src
  assert_equal [
    "/images/posts/#{CANONICAL_SLUG}-480w.webp 480w",
    "/images/posts/#{CANONICAL_SLUG}-768w.webp 768w",
    "/images/posts/#{CANONICAL_SLUG}-1200w.webp 1200w"
  ].join(", "), cover.srcset
  assert_equal 1200, cover.width
  assert_equal 630, cover.height
  assert_predicate cover, :frozen?
  assert_predicate cover.variants, :frozen?
  cover.variants.each do |variant|
    assert_predicate variant, :frozen?
    assert_predicate variant.src, :frozen?
  end
  assert_raises(FrozenError) { cover.variants << cover.variants.first }
  assert_raises(FrozenError) { cover.variants.first.src << "-mutated" }
  assert_equal original_hash, cover.hash
end
```

Replace the caller-ownership test with:

```ruby
test "initialization does not freeze the caller's variant array or source strings" do
  sources = SIZES.map { |width, _height| +"/images/posts/example-#{width}w.webp" }
  variants = SIZES.map.with_index do |(width, height), index|
    Writing::Cover::Variant.new(src: sources.fetch(index), width: width, height: height)
  end

  cover = Writing::Cover.new(variants: variants)

  refute_same variants, cover.variants
  refute_predicate variants, :frozen?
  sources.each { refute_predicate _1, :frozen? }
end
```

Keep the all-absent test, changing its description to "find returns nil when
all responsive candidates are absent".

Generate one test per missing candidate:

```ruby
SIZES.each_key do |missing_width|
  test "find rejects a responsive set missing #{missing_width}w" do
    with_cover_root do |root|
      copy_variants(root, slug: "partial", except: [missing_width])
      path = root.join("partial-#{missing_width}w.webp")

      error = assert_raises(Writing::Cover::Invalid) do
        Writing::Cover.find(resource("partial"), root: root)
      end
      assert_equal "Invalid WebP cover variant: #{path}", error.message
    end
  end
end
```

Replace the existing wrong-format and corrupt tests, and add lossy and
wrong-dimension cases, using a complete copied set before replacing one file:

```ruby
test "find rejects non-WebP content with a variant suffix" do
  with_cover_root do |root|
    copy_variants(root, slug: "wrong-format")
    path = root.join("wrong-format-480w.webp")
    path.binwrite(Base64.strict_decode64(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    ))

    assert_invalid_variant("wrong-format", path, root)
  end
end

test "find rejects a lossy WebP variant" do
  with_cover_root do |root|
    copy_variants(root, slug: "lossy")
    path = root.join("lossy-480w.webp")
    path.binwrite(Base64.strict_decode64(LOSSY_WEBP))

    assert_equal :webp, FastImage.type(path.to_s)
    assert_equal "VP8 ", path.binread(4, 12)
    assert_invalid_variant("lossy", path, root)
  end
end

test "find rejects a lossless WebP variant with unreadable dimensions" do
  with_cover_root do |root|
    copy_variants(root, slug: "corrupt")
    path = root.join("corrupt-480w.webp")
    path.binwrite("RIFF" + [8].pack("V") + "WEBP" + "VP8L")

    assert_equal :webp, FastImage.type(path.to_s)
    assert_equal "VP8L", path.binread(4, 12)
    assert_nil FastImage.size(path.to_s)
    assert_invalid_variant("corrupt", path, root)
  end
end

test "find rejects a variant whose dimensions do not match its suffix" do
  with_cover_root do |root|
    copy_variants(root, slug: "wrong-size")
    path = root.join("wrong-size-768w.webp")
    FileUtils.cp(canonical_variant(480), path)

    assert_equal [480, 252], FastImage.size(path.to_s)
    assert_invalid_variant("wrong-size", path, root)
  end
end
```

Add these private helpers:

```ruby
def copy_variants(root, slug:, except: [])
  SIZES.each_key do |width|
    next if except.include?(width)

    FileUtils.cp(canonical_variant(width), root.join("#{slug}-#{width}w.webp"))
  end
end

def canonical_variant(width)
  Rails.root.join("public/images/posts/#{CANONICAL_SLUG}-#{width}w.webp")
end

def assert_invalid_variant(slug, path, root)
  error = assert_raises(Writing::Cover::Invalid) do
    Writing::Cover.find(resource(slug), root: root)
  end
  assert_equal "Invalid WebP cover variant: #{path}", error.message
end
```

Update `PostCoverHelperTest` to expect the 1200w fallback URL:

```ruby
assert_equal "/images/posts/pettis-good-tariffs-vs-bad-1200w.webp", cover.src
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/models/writing/cover_test.rb \
  test/helpers/post_cover_helper_test.rb
```

Expected: FAIL because `Writing::Cover::Variant`, `variants`, and `srcset` do
not exist and the current lookup still uses the unsuffixed file.

- [ ] **Step 3: Implement the immutable responsive cover model**

Replace `app/models/writing/cover.rb` with:

```ruby
# frozen_string_literal: true

require "fastimage"

module Writing
  class Cover < Literal::Data
    class Invalid < StandardError; end

    class Variant < Literal::Data
      prop :src, String
      prop :width, Integer
      prop :height, Integer

      private

      def after_initialize
        @src = src.dup.freeze
      end
    end

    SIZES = {
      480 => 252,
      768 => 403,
      1200 => 630
    }.freeze

    prop :variants, _Array(Variant)

    def self.find(resource, root: Rails.root.join("public/images/posts"))
      slug = Pathname(resource.request_path.to_s).basename.to_s
      paths = SIZES.to_h do |width, height|
        [Pathname(root).join("#{slug}-#{width}w.webp"), [width, height]]
      end
      return unless paths.keys.any?(&:file?)

      variants = paths.map do |path, dimensions|
        invalid!(path) unless valid?(path, dimensions)

        Variant.new(
          src: "/images/posts/#{path.basename}",
          width: dimensions.first,
          height: dimensions.last
        )
      end
      new(variants: variants)
    end

    def self.valid?(path, dimensions)
      return false unless path.file?
      return false unless FastImage.type(path.to_s) == :webp
      return false unless path.binread(4, 12) == "VP8L"

      image = Sitepress::Image.new(path: path)
      [image.width, image.height] == dimensions
    end
    private_class_method :valid?

    def self.invalid!(path)
      raise Invalid, "Invalid WebP cover variant: #{path}"
    end
    private_class_method :invalid!

    def src = fallback.src

    def srcset
      variants.map { |variant| "#{variant.src} #{variant.width}w" }.join(", ")
    end

    def width = fallback.width

    def height = fallback.height

    private

    def fallback = variants.last

    def after_initialize
      @variants = variants.dup.freeze
    end
  end
end
```

- [ ] **Step 4: Run focused and full tests and verify GREEN**

Run:

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/models/writing/cover_test.rb \
  test/helpers/post_cover_helper_test.rb
PARALLEL_WORKERS=1 bin/rails test
```

Expected: PASS with no failures or errors. The application now reads only
width-suffixed variants; unsuffixed masters are still present but unused.

- [ ] **Step 5: Commit the cover contract**

```bash
git add app/models/writing/cover.rb \
  test/models/writing/cover_test.rb \
  test/helpers/post_cover_helper_test.rb
git commit -m "feat(images): Model responsive cover metadata"
```

### Task 3: Render Context-Aware Responsive Markup

**Files:**

- Modify: `test/views/layouts/application_layout_test.rb`
- Modify: `test/components/collection_component_test.rb`
- Modify: `test/integration/article_layout_test.rb`
- Modify: `test/integration/writing_collection_test.rb`
- Modify: `app/views/layouts/application_layout.rb`
- Modify: `app/views/components/collection_component.rb`

- [ ] **Step 1: Add failing article and homepage markup assertions**

Use the canonical cover in the layout test instead of directly constructing
the old three-property object:

```ruby
Resource = Data.define(:request_path)

def canonical_cover
  Writing::Cover.find(Resource.new("/writing/pettis-good-tariffs-vs-bad"))
end
```

In the article cover test, assert:

```ruby
assert_equal "/images/posts/pettis-good-tariffs-vs-bad-1200w.webp", image["src"]
assert_equal canonical_cover.srcset, image["srcset"]
assert_equal(
  "(max-width: 48rem) min(calc(100vw - clamp(2.2rem, 8vw, 6rem)), 36rem), 22rem",
  image["sizes"]
)
assert_equal "1200", image["width"]
assert_equal "630", image["height"]
assert_equal "", image["alt"]
```

In the homepage component test, change the fallback `src` expectation to the
1200w URL and add:

```ruby
cover = Writing::Cover.find(Resource.new(
  "/writing/pettis-good-tariffs-vs-bad",
  {"title" => "Michael Pettis"}
))

assert_equal cover.srcset, image["srcset"]
assert_equal(
  "(max-width: 48rem) calc(100vw - clamp(2.2rem, 8vw, 6rem)), min(60vw, 47rem)",
  image["sizes"]
)
```

In `ArticleLayoutTest`, parse the cover image and assert the same article
`src`, `srcset`, `sizes`, width, height, and empty alt values. In the first
`WritingCollectionTest`, replace the old fallback selector and assert the same
homepage values from the response's feature image. Keep the existing route,
title, accessibility, count, and text-only assertions.

- [ ] **Step 2: Run rendering tests and verify RED**

Run:

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/views/layouts/application_layout_test.rb \
  test/components/collection_component_test.rb \
  test/integration/article_layout_test.rb \
  test/integration/writing_collection_test.rb
```

Expected: FAIL because the rendered images do not have `srcset` or `sizes`.

- [ ] **Step 3: Render `srcset` and context-specific `sizes`**

In `ApplicationLayout`, define:

```ruby
ARTICLE_COVER_SIZES = \
  "(max-width: 48rem) min(calc(100vw - clamp(2.2rem, 8vw, 6rem)), 36rem), 22rem"
```

Add these attributes to the existing article `img` call:

```ruby
srcset: cover.srcset,
sizes: ARTICLE_COVER_SIZES,
```

In `CollectionComponent`, define:

```ruby
FEATURE_COVER_SIZES = \
  "(max-width: 48rem) calc(100vw - clamp(2.2rem, 8vw, 6rem)), min(60vw, 47rem)"
```

Add these attributes to the existing homepage feature `img` call:

```ruby
srcset: cover.srcset,
sizes: FEATURE_COVER_SIZES,
```

Do not change CSS, `alt`, `aria-label`, width, height, crop, or missing-cover
branches.

- [ ] **Step 4: Run focused and full tests and verify GREEN**

Run:

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/views/layouts/application_layout_test.rb \
  test/components/collection_component_test.rb \
  test/integration/article_layout_test.rb \
  test/integration/writing_collection_test.rb \
  test/integration/pages_smoke_test.rb
PARALLEL_WORKERS=1 bin/rails test
```

Expected: PASS with no failures or errors.

- [ ] **Step 5: Commit responsive rendering**

```bash
git add app/views/layouts/application_layout.rb \
  app/views/components/collection_component.rb \
  test/views/layouts/application_layout_test.rb \
  test/components/collection_component_test.rb \
  test/integration/article_layout_test.rb \
  test/integration/writing_collection_test.rb
git commit -m "feat(images): Render responsive cover candidates"
```

### Task 4: Remove Unsuffixed Cover Compatibility

**Files:**

- Modify: `test/models/writing/cover_assets_test.rb`
- Modify: `CLAUDE.md`
- Delete: `public/images/posts/capture-request-referrer-via-css.webp`
- Delete: `public/images/posts/embrace_the_cascade_in_your_rails_app.webp`
- Delete: `public/images/posts/markdown-in-rails-with-phlex-and-sitepress.webp`
- Delete: `public/images/posts/national-accounting.webp`
- Delete: `public/images/posts/pettis-good-tariffs-vs-bad.webp`
- Delete: `public/images/posts/tag-overriding-in-phlex-and-markdown.webp`
- Delete: `public/images/posts/why-I-made-this-site-with-phlex-sitepress-and-rails.webp`

- [ ] **Step 1: Tighten the inventory test and verify RED**

Replace both transitional inventory tests with one final test. Keep `EXPECTED`
and `SIZES`:

```ruby
test "repository contains only canonical responsive lossless WebP covers" do
  root = Rails.root.join("public/images/posts")
  expected = EXPECTED.product(SIZES.keys).map do |slug, width|
    "#{slug}-#{width}w.webp"
  end.sort
  files = root.children.select(&:file?)

  assert_equal expected, files.map { _1.basename.to_s }.sort

  files.each do |path|
    width = path.basename.to_s.match(/-(480|768|1200)w\.webp\z/)[1].to_i
    image = Sitepress::Image.new(path: path)

    assert_equal :webp, FastImage.type(path.to_s), path.to_s
    assert_equal "VP8L", path.binread(4, 12), path.to_s
    assert_equal [width, SIZES.fetch(width)], [image.width, image.height], path.to_s
  end
end
```

Run:

```bash
PARALLEL_WORKERS=1 bin/rails test test/models/writing/cover_assets_test.rb
```

Expected: FAIL because the seven unsuffixed master files remain.

- [ ] **Step 2: Delete unsuffixed files and update repository guidance**

Remove only these obsolete files:

```bash
git rm public/images/posts/capture-request-referrer-via-css.webp
git rm public/images/posts/embrace_the_cascade_in_your_rails_app.webp
git rm public/images/posts/markdown-in-rails-with-phlex-and-sitepress.webp
git rm public/images/posts/national-accounting.webp
git rm public/images/posts/pettis-good-tariffs-vs-bad.webp
git rm public/images/posts/tag-overriding-in-phlex-and-markdown.webp
git rm public/images/posts/why-I-made-this-site-with-phlex-sitepress-and-rails.webp
```

Change the `CLAUDE.md` post-cover section to:

```markdown
Post covers are supplied directly as canonical 480w, 768w, and 1200w
lossless WebP variants in `public/images/posts`, named
`<slug>-<width>w.webp`. `Writing::Cover` validates a complete VP8L set and
exact `Sitepress::Image` dimensions. There is no unsuffixed, alternate-format,
partial-set, or dimensionless fallback.
```

- [ ] **Step 3: Run inventory and full tests and verify GREEN**

Run:

```bash
PARALLEL_WORKERS=1 bin/rails test test/models/writing/cover_assets_test.rb
PARALLEL_WORKERS=1 bin/rails test
```

Expected: PASS with no failures or errors. The directory contains exactly 21
files and application behavior no longer depends on an unsuffixed URL.

- [ ] **Step 4: Commit compatibility removal**

```bash
git add CLAUDE.md test/models/writing/cover_assets_test.rb
git add -u public/images/posts
git commit -m "refactor(images): Remove unsuffixed cover compatibility"
```

### Task 5: Full Verification

**Files:** No new files expected.

- [ ] **Step 1: Run focused feature tests**

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/models/writing/cover_assets_test.rb \
  test/models/writing/cover_test.rb \
  test/helpers/post_cover_helper_test.rb \
  test/views/layouts/application_layout_test.rb \
  test/components/collection_component_test.rb \
  test/integration/article_layout_test.rb \
  test/integration/writing_collection_test.rb \
  test/integration/pages_smoke_test.rb
```

Expected: PASS with no failures or errors.

- [ ] **Step 2: Run full automated verification**

```bash
PARALLEL_WORKERS=1 bin/rails test
bin/rails test:system
bundle exec standardrb
bundle check
git diff --check main...HEAD
```

Expected: all commands exit zero.

- [ ] **Step 3: Recheck repository and binary invariants**

```bash
find public/images/posts -maxdepth 1 -type f -print | sort
webpinfo public/images/posts/*.webp
```

Expected: exactly 21 files, all width-suffixed. Each file reports `VP8L`,
`Format: Lossless (2)`, its expected dimensions, and `No error detected.`

Run a Rails-level invariant check:

```bash
bin/rails runner '
sizes = {480 => 252, 768 => 403, 1200 => 630}
paths = Rails.root.glob("public/images/posts/*.webp")
abort "expected 21 variants" unless paths.size == 21
paths.each do |path|
  width = path.basename.to_s.match(/-(480|768|1200)w\.webp\z/)&.[](1)&.to_i
  abort "invalid name: #{path}" unless width
  image = Sitepress::Image.new(path: path)
  abort "invalid image: #{path}" unless path.binread(4, 12) == "VP8L" &&
    [image.width, image.height] == [width, sizes.fetch(width)]
end
'
```

Expected: exit zero with no output.

- [ ] **Step 4: Review final HTML and repository state**

Use integration-test response output or a local server to inspect `/` and
`/writing/pettis-good-tariffs-vs-bad`. Confirm each cover has the exact
fallback `src`, three-candidate `srcset`, context-specific `sizes`, 1200-by-630
intrinsic attributes, empty alt text, and no console/server errors. Confirm a
resource without any candidates remains text-only.

```bash
git status --short
git log --oneline --decorate -6
git diff --stat main...HEAD
```

Expected: a clean worktree, one design commit, one plan commit, and four
implementation commits containing only intentional responsive-cover changes.

### Task 6: Finish the Branch

- [ ] **Step 1: Request final code review**

Use `superpowers-ruby:requesting-code-review` against `main...HEAD`. Address
all verified findings and rerun affected tests.

- [ ] **Step 2: Apply verification-before-completion**

Use `superpowers-ruby:verification-before-completion` and rerun the full test,
system, style, dependency, diff, inventory, and WebP checks immediately before
making any completion claim.

- [ ] **Step 3: Offer integration choices**

Use `superpowers-ruby:finishing-a-development-branch` to offer local merge,
push/PR, keep, or discard. Do not push or merge without the user's selection.
