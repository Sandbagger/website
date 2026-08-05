# Sitepress 5 Native Sources and Covers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the site's Sitepress 4 asset compatibility usage, convert all canonical post covers to lossless WebP, and render intrinsic cover dimensions through `Sitepress::Image`.

**Architecture:** Writing resources use `Sitepress::Resource#source` and `Sitepress::Page` exclusively. A focused `Writing::Cover` value object finds one canonical WebP per slug, verifies its actual file type and dimensions, and supplies immutable rendering data to the existing helper, layout, and collection component. Covers remain directly served from `public/images/posts`; the obsolete SVG generator is removed rather than replaced.

**Tech Stack:** Ruby 3.3, Rails 8, Sitepress 5.0.0.beta4, Literal, Phlex, Minitest, FastImage through Sitepress, headless Chrome, cwebp/webpinfo.

---

## File Structure

- Create `app/models/writing/cover.rb` — canonical WebP discovery, type and dimension validation, and immutable rendering metadata.
- Create `test/models/writing/cover_test.rb` — cover lookup, missing-cover, wrong-format, and invalid-dimension behavior.
- Create `test/models/writing/cover_assets_test.rb` — repository-level cover inventory, content type, and dimensions.
- Create `test/integration/sitepress_native_source_api_test.rb` — regression guard against Sitepress asset compatibility APIs.
- Modify `lib/writing/resource_pipeline.rb` — use `source`, require `Sitepress::Page`, and remove the redundant resource subclass.
- Modify `app/models/writing/catalogue.rb` — derive writing paths from `source.path`.
- Modify `app/controllers/sitepress/site_controller.rb` — derive paths from `source` and pass cover objects.
- Modify `app/helpers/post_cover_helper.rb` — return `Writing::Cover` rather than an SVG URL string.
- Modify `app/views/layouts/application_layout.rb` — render cover `src`, `width`, and `height`.
- Modify `app/views/components/collection_component.rb` — render the same cover metadata for the homepage feature.
- Modify Sitepress resource, catalogue, helper, layout, component, and integration tests to use the native source and cover contracts.
- Delete `lib/post_image_generator.rb`, `lib/tasks/post_images.rake`, and `test/lib/post_image_generator_test.rb` — obsolete SVG generation workflow.
- Modify `CLAUDE.md` — remove the obsolete generator command and document the direct, validated-WebP cover policy.
- Replace the eleven files under `public/images/posts/*.svg` with seven canonical `*.webp` files.

## Plan Document Checkpoint

Before implementation, commit this reviewed plan by itself:

```bash
git add docs/superpowers/plans/2026-08-05-sitepress-5-native-sources-and-covers.md
git commit -m "docs(sitepress): Plan native sources and covers"
```

### Task 1: Remove Sitepress Asset Compatibility APIs

**Files:**

- Create: `test/integration/sitepress_native_source_api_test.rb`
- Modify: `test/lib/writing/resource_pipeline_test.rb`
- Modify: `test/models/writing/catalogue_test.rb`
- Modify: `test/integration/writing_resource_mapping_test.rb`
- Modify: `test/integration/writing_collection_test.rb`
- Modify: `test/integration/writing_publication_access_test.rb`
- Modify: `lib/writing/resource_pipeline.rb`
- Modify: `app/models/writing/catalogue.rb`
- Modify: `app/controllers/sitepress/site_controller.rb`

- [ ] **Step 1: Write the failing native-source regression tests**

Create `test/integration/sitepress_native_source_api_test.rb` so future code cannot silently return to Sitepress's compatibility aliases:

```ruby
# frozen_string_literal: true

require "test_helper"

class SitepressNativeSourceApiTest < ActiveSupport::TestCase
  SOURCE_FILES = Rails.root.glob("{app,lib,test}/**/*.{rb,rake}")
    .reject { |path| path.basename.to_s == "sitepress_native_source_api_test.rb" }
    .freeze
  LEGACY_PATTERNS = {
    "Sitepress asset constant" => /Sitepress::A(?:sset)/,
    "resource asset reader" => /\.a(?:sset)\b/,
    "resource asset keyword" => /\ba(?:sset):/
  }.freeze

  test "application and tests use only Sitepress 5 source APIs" do
    violations = SOURCE_FILES.flat_map do |path|
      source = path.read
      LEGACY_PATTERNS.filter_map do |label, pattern|
        "#{path.relative_path_from(Rails.root)}: #{label}" if source.match?(pattern)
      end
    end

    assert_empty violations, violations.join("\n")
  end
end
```

Add a resource-pipeline test that inserts a writing resource backed by
`Sitepress::Static` and expects `Writing::ResourcePipeline::Invalid` before
the tree is mutated. Strengthen the extensionless-preview test to assert that
the replacement is exactly `Sitepress::Resource`, retains the identical
`source`, and is renderable.

- [ ] **Step 2: Run the tests and verify RED**

Run:

```bash
bin/rails test \
  test/integration/sitepress_native_source_api_test.rb \
  test/lib/writing/resource_pipeline_test.rb
```

Expected: FAIL because legacy asset APIs remain and a non-page writing source
is not rejected.

- [ ] **Step 3: Implement the native source boundary**

In `Writing::ResourcePipeline`:

```ruby
def process(root)
  entries = writing_resources(root).map do |resource|
    validate_page_source!(resource)
    path = Path.new(resource.source.path)
    target = canonical_target(path) if path.post?

    Entry.new(resource:, path:, target:)
  end

  # Existing validation and mutation sequence remains unchanged.
end

def validate_page_source!(resource)
  return if resource.source.is_a?(Sitepress::Page)

  fail Invalid,
    "Writing resource #{resource.source.path} must use Sitepress::Page, " \
    "got #{resource.source.class}"
end
```

Replace every `resource.asset.path` with `resource.source.path`. Delete
`DraftPreviewResource` and remap an extensionless draft with:

```ruby
node.resources.add Sitepress::Resource.new(
  source: resource.source,
  node: node,
  format: :html,
  handler: :markerb,
  mime_type: MIME::Types["text/html"].first
)
```

Update test factories to create `Sitepress::Page.new(path: source_path)`, set
its data where required, and create resources with `source:`. Update all
catalogue, controller, snapshot, and integration assertions to use `source`.
Do not modify Rails `asset_path` calls.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run:

```bash
bin/rails test \
  test/integration/sitepress_native_source_api_test.rb \
  test/lib/writing/resource_pipeline_test.rb \
  test/models/writing/catalogue_test.rb \
  test/integration/writing_resource_mapping_test.rb \
  test/integration/writing_collection_test.rb \
  test/integration/writing_publication_access_test.rb
bin/rails test
```

Expected: PASS with no failures or errors.

- [ ] **Step 5: Verify the legacy API is absent**

Run:

```bash
if rg -n 'Sitepress::Asset|\basset:\s|\.asset\b|AssetNodeMapper' \
  app config lib test --glob '!app/assets/builds/**'; then
  echo 'Sitepress compatibility API remains' >&2
  exit 1
fi
```

Expected: the absence assertion exits zero. Rails `asset_path` is deliberately
excluded by these patterns.

- [ ] **Step 6: Commit the native source migration**

```bash
git add app/controllers/sitepress/site_controller.rb \
  app/models/writing/catalogue.rb \
  lib/writing/resource_pipeline.rb \
  test/integration/sitepress_native_source_api_test.rb \
  test/integration/writing_collection_test.rb \
  test/integration/writing_publication_access_test.rb \
  test/integration/writing_resource_mapping_test.rb \
  test/lib/writing/resource_pipeline_test.rb \
  test/models/writing/catalogue_test.rb
git commit -m "refactor(sitepress): Adopt native source APIs"
```

### Task 2: Create and Validate WebP Replacements

**Files:**

- Create: `test/models/writing/cover_assets_test.rb`
- Create: `public/images/posts/*.webp` (seven files)

- [ ] **Step 1: Write the failing cover inventory test**

Create `test/models/writing/cover_assets_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"
require "fastimage"

class Writing::CoverAssetsTest < ActiveSupport::TestCase
  EXPECTED = %w[
    capture-request-referrer-via-css
    embrace_the_cascade_in_your_rails_app
    markdown-in-rails-with-phlex-and-sitepress
    national-accounting
    pettis-good-tariffs-vs-bad
    tag-overriding-in-phlex-and-markdown
    why-I-made-this-site-with-phlex-sitepress-and-rails
  ].freeze

  test "repository contains canonical dimensioned WebP covers" do
    root = Rails.root.join("public/images/posts")
    webps = root.glob("*.webp")

    assert_equal EXPECTED, webps.map { _1.basename(".webp").to_s }.sort
    webps.each do |path|
      image = Sitepress::Image.new(path:)
      assert_equal :webp, FastImage.type(path.to_s), path.to_s
      assert_equal [1200, 630], [image.width, image.height], path.to_s
    end
  end
end
```

- [ ] **Step 2: Run the inventory test and verify RED**

Run:

```bash
bin/rails test test/models/writing/cover_assets_test.rb
bin/rails test
```

Expected: FAIL because the repository has no WebPs.

- [ ] **Step 3: Render canonical SVGs and encode lossless WebP**

For these canonical stems:

```text
capture-request-referrer-via-css
embrace_the_cascade_in_your_rails_app
markdown-in-rails-with-phlex-and-sitepress
national-accounting
pettis-good-tariffs-vs-bad
tag-overriding-in-phlex-and-markdown
why-I-made-this-site-with-phlex-sitepress-and-rails
```

Render each canonical `.svg` through headless Google Chrome at one device
pixel per CSS pixel, verify the intermediate PNG, and encode it with lossless
WebP. Run this complete checked Zsh script from the worktree root:

```bash
set -euo pipefail

cover_conversion_tmp=$(mktemp -d)
cover_stems=(
  capture-request-referrer-via-css
  embrace_the_cascade_in_your_rails_app
  markdown-in-rails-with-phlex-and-sitepress
  national-accounting
  pettis-good-tariffs-vs-bad
  tag-overriding-in-phlex-and-markdown
  why-I-made-this-site-with-phlex-sitepress-and-rails
)

for cover_stem in $cover_stems; do
  cover_svg="$PWD/public/images/posts/$cover_stem.svg"
  cover_png="$cover_conversion_tmp/$cover_stem.png"
  cover_webp="$PWD/public/images/posts/$cover_stem.webp"
  chrome_profile="$cover_conversion_tmp/chrome-$cover_stem"

  test -f "$cover_svg"
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
    --headless=new \
    --disable-gpu \
    --hide-scrollbars \
    --force-device-scale-factor=1 \
    --window-size=1200,630 \
    --user-data-dir="$chrome_profile" \
    --screenshot="$cover_png" \
    "file://$cover_svg"

  sips -g pixelWidth "$cover_png" | rg -q 'pixelWidth: 1200'
  sips -g pixelHeight "$cover_png" | rg -q 'pixelHeight: 630'
  cwebp -quiet -lossless -exact "$cover_png" -o "$cover_webp"
done
```

Keep all SVG inputs after this task. If any command exits non-zero, stop
without changing or deleting an input.

- [ ] **Step 4: Verify format, codec, dimensions, and appearance**

For every generated file, run this checked loop while the SVG inputs still
exist:

```bash
set -euo pipefail

cover_stems=(
  capture-request-referrer-via-css
  embrace_the_cascade_in_your_rails_app
  markdown-in-rails-with-phlex-and-sitepress
  national-accounting
  pettis-good-tariffs-vs-bad
  tag-overriding-in-phlex-and-markdown
  why-I-made-this-site-with-phlex-sitepress-and-rails
)

for cover_stem in $cover_stems; do
  cover_webp="public/images/posts/$cover_stem.webp"
  webpinfo "$cover_webp"
  webpinfo "$cover_webp" | rg -q 'Chunk VP8L'
  webpinfo "$cover_webp" | rg -q 'Width: 1200'
  webpinfo "$cover_webp" | rg -q 'Height: 630'
  webpinfo "$cover_webp" | rg -q 'Format: Lossless \(2\)'
  webpinfo "$cover_webp" | rg -q 'No error detected'
done

bin/rails runner '
  paths = Rails.root.glob("public/images/posts/*.webp")
  abort "Expected seven WebPs" unless paths.size == 7
  paths.each do |path|
    image = Sitepress::Image.new(path: path)
    abort "Invalid dimensions: #{path}" unless [image.width, image.height] == [1200, 630]
  end
'
```

Expected for each: `Chunk VP8L`, `Width: 1200`, `Height: 630`,
`Format: Lossless (2)`, and `No error detected`.

Use the local image viewer to inspect each canonical SVG and its final WebP.
Check that title text, gradient, circles, crop, and background are intact in
all seven comparisons.

- [ ] **Step 5: Run the inventory test and verify GREEN**

Run:

```bash
bin/rails test test/models/writing/cover_assets_test.rb
bin/rails test
```

Expected: PASS with no failures or errors. Existing SVG consumers continue to
work until Task 3 migrates them atomically.

- [ ] **Step 6: Commit the verified WebP replacements**

```bash
git add public/images/posts/*.webp test/models/writing/cover_assets_test.rb
git commit -m "feat(images): Add lossless WebP post covers"
```

### Task 3: Add and Render the Strict Sitepress Cover Model

**Files:**

- Create: `app/models/writing/cover.rb`
- Create: `test/models/writing/cover_test.rb`
- Modify: `app/helpers/post_cover_helper.rb`
- Modify: `test/helpers/post_cover_helper_test.rb`
- Modify: `app/controllers/sitepress/site_controller.rb`
- Modify: `app/views/layouts/application_layout.rb`
- Modify: `app/views/components/collection_component.rb`
- Modify: `test/views/layouts/application_layout_test.rb`
- Modify: `test/components/collection_component_test.rb`
- Modify: `test/integration/writing_collection_test.rb`

- [ ] **Step 1: Write failing cover lookup and validation tests**

Use a small request-path value object and temporary directories. Cover:

- A canonical repository WebP returns `/images/posts/<slug>.webp`, 1200, and
  630.
- A missing WebP returns `nil`.
- A valid one-pixel PNG created from
  `Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")`
  and written to `<slug>.webp` first proves
  `FastImage.type(path) == :png`, then raises `Writing::Cover::Invalid` and
  names the path.
- A corrupt WebP fixture created as
  `"RIFF" + [4].pack("V") + "WEBP"` first proves
  `FastImage.type(path) == :webp` and `FastImage.size(path).nil?`, then raises
  the same error. This distinguishes unreadable dimensions from wrong format.
- `PostCoverHelper#post_cover` returns the `Writing::Cover` object. Construct
  the removed legacy method symbol from `%w[post cover path].join("_")` when
  asserting it is absent, so final source searches do not match the test.
- Article and homepage feature images render the cover's `src`, `width`, and
  `height` while missing covers keep the text-only layouts.

Update the layout test to pass a real `Writing::Cover`, render `article_page`,
and assert:

```ruby
assert_equal "/images/posts/example.webp", image["src"]
assert_equal "1200", image["width"]
assert_equal "630", image["height"]
assert_equal "", image["alt"]
```

Add the same intrinsic-dimension assertions to the homepage feature component
and integration tests. Preserve the existing missing-cover tests.

- [ ] **Step 2: Run the tests and verify RED**

Run:

```bash
bin/rails test \
  test/models/writing/cover_test.rb \
  test/helpers/post_cover_helper_test.rb \
  test/views/layouts/application_layout_test.rb \
  test/components/collection_component_test.rb \
  test/integration/writing_collection_test.rb
```

Expected: FAIL because `Writing::Cover` and `post_cover` do not exist and
rendered covers do not carry intrinsic dimensions.

- [ ] **Step 3: Implement `Writing::Cover`, migrate every consumer, and render dimensions**

Create `app/models/writing/cover.rb`:

```ruby
# frozen_string_literal: true

require "fastimage"

module Writing
  class Cover < Literal::Data
    class Invalid < StandardError; end

    prop :src, String
    prop :width, Integer
    prop :height, Integer

    class << self
      def find(resource, root: Rails.root.join("public/images/posts"))
        slug = Pathname(resource.request_path.to_s).basename.to_s
        filename = "#{slug}.webp"
        path = Pathname(root).join(filename)
        return unless path.file?

        image = Sitepress::Image.new(path:)
        validate!(path, image)
        new(
          src: "/images/posts/#{filename}",
          width: image.width,
          height: image.height
        )
      end

      private

      def validate!(path, image)
        valid = FastImage.type(path.to_s) == :webp &&
          image.width.to_i.positive? && image.height.to_i.positive?
        return if valid

        fail Invalid, "Invalid WebP cover: #{path}"
      end
    end
  end
end
```

Replace `post_cover_path` with:

```ruby
def post_cover(resource)
  Writing::Cover.find(resource)
end
```

Do not retain a method alias or SVG lookup.

Update the Sitepress controller atomically with the helper:

```ruby
def attach_cover(layout, page)
  cover = post_cover(page)
  layout.cover_image(cover, alt: "") if cover
end
```

In `ApplicationLayout`, store and render the complete cover contract:

```ruby
def cover_image(cover, alt: nil)
  @cover_image = {cover:, alt:}
end

# Inside article_page's existing `if @cover_image` branch:
cover = @cover_image.fetch(:cover)
img(
  src: cover.src,
  width: cover.width,
  height: cover.height,
  alt: @cover_image[:alt],
  class: "article-cover"
)
```

In `CollectionComponent#feature`, call `post_cover(resource)` and render the
same `src`, `width`, and `height` attributes. Keep decorative `alt=""`, all
existing CSS classes, accessibility labels, and text-only branches.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run:

```bash
bin/rails test \
  test/models/writing/cover_test.rb \
  test/helpers/post_cover_helper_test.rb \
  test/models/writing/cover_assets_test.rb \
  test/views/layouts/application_layout_test.rb \
  test/components/collection_component_test.rb \
  test/integration/writing_collection_test.rb \
  test/integration/pages_smoke_test.rb
bin/rails test
```

Expected: PASS with no failures or errors.

- [ ] **Step 5: Commit the strict cover model**

```bash
git add app/models/writing/cover.rb app/helpers/post_cover_helper.rb \
  app/controllers/sitepress/site_controller.rb \
  app/views/layouts/application_layout.rb \
  app/views/components/collection_component.rb \
  test/models/writing/cover_test.rb \
  test/helpers/post_cover_helper_test.rb \
  test/views/layouts/application_layout_test.rb \
  test/components/collection_component_test.rb \
  test/integration/writing_collection_test.rb
git commit -m "feat(sitepress): Render strict WebP cover metadata"
```

### Task 4: Remove the SVG Compatibility Workflow

**Files:**

- Modify: `test/models/writing/cover_assets_test.rb`
- Delete: `public/images/posts/*.svg` (eleven files)
- Delete: `lib/post_image_generator.rb`
- Delete: `lib/tasks/post_images.rake`
- Delete: `test/lib/post_image_generator_test.rb`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Tighten the cover inventory test and verify RED**

Add the final no-SVG invariant to `Writing::CoverAssetsTest`:

```ruby
assert_empty root.glob("*.svg")
```

Run:

```bash
bin/rails test test/models/writing/cover_assets_test.rb
```

Expected: FAIL because eleven SVG files remain.

- [ ] **Step 2: Delete the obsolete workflow and update guidance**

Delete all eleven post-cover SVGs, including the `.html.svg` duplicates.
Delete `PostImageGenerator`, `images:generate_posts`, and their test file.

Update `CLAUDE.md`: remove the generator command and replace the generator
section with the policy that post covers are supplied directly as canonical
1200-by-630 lossless WebP files, validated through `Writing::Cover`, with no
SVG or alternate-format fallback.

- [ ] **Step 3: Run the inventory and full suite and verify GREEN**

```bash
bin/rails test test/models/writing/cover_assets_test.rb
if bundle exec rake -T | rg -q 'images:generate_posts'; then
  echo 'obsolete images:generate_posts task remains' >&2
  exit 1
fi
bin/rails test
```

Expected: PASS with no failures or errors; the absence assertion exits zero.

- [ ] **Step 4: Commit the SVG workflow removal**

```bash
git add CLAUDE.md test/models/writing/cover_assets_test.rb
git add -u public/images/posts lib/post_image_generator.rb \
  lib/tasks/post_images.rake test/lib/post_image_generator_test.rb
git commit -m "refactor(images): Remove SVG cover compatibility"
```

### Task 5: Full Verification

**Files:** No new files expected.

- [ ] **Step 1: Run focused feature tests**

```bash
bin/rails test \
  test/integration/sitepress_native_source_api_test.rb \
  test/lib/writing/resource_pipeline_test.rb \
  test/models/writing/catalogue_test.rb \
  test/models/writing/cover_assets_test.rb \
  test/models/writing/cover_test.rb \
  test/helpers/post_cover_helper_test.rb \
  test/views/layouts/application_layout_test.rb \
  test/components/collection_component_test.rb \
  test/integration/writing_collection_test.rb \
  test/integration/pages_smoke_test.rb
```

Expected: PASS with no failures or errors.

- [ ] **Step 2: Run full automated verification**

```bash
bin/rails test
bin/rails test:system
bundle exec standardrb
bundle check
git diff --check
```

Expected: all commands exit zero.

- [ ] **Step 3: Recheck compatibility and image invariants**

```bash
if rg -n 'Sitepress::Asset|\basset:\s|\.asset\b|AssetNodeMapper|post_cover_path|images/posts/[^"[:space:]]*\.svg' \
  app config lib test --glob '!app/assets/builds/**'; then
  echo 'Sitepress compatibility or post-cover SVG reference remains' >&2
  exit 1
fi
if find public/images/posts -maxdepth 1 -type f -name '*.svg' -print -quit | rg -q .; then
  echo 'post-cover SVG file remains' >&2
  exit 1
fi
find public/images/posts -maxdepth 1 -type f -print | sort
```

Expected: the compatibility search has no output and the directory contains
exactly seven `.webp` files.

Run `webpinfo` across all seven files and verify each reports `VP8L`, 1200 by
630, and `Format: Lossless (2)`. Use `Sitepress::Image` to verify identical
dimensions.

- [ ] **Step 4: Inspect the rendered site**

Open the home page and one covered article. Verify the covers render, retain
their aspect ratio and crop, reserve layout space before load, and have width
and height attributes. Open the extensionless Tailwind draft and confirm its
text-only layout still renders.

- [ ] **Step 5: Review repository state and commits**

```bash
git status --short
git log --oneline --decorate -5
git diff main...HEAD --stat
```

Expected: only intentional feature changes, a clean feature worktree, one
plan-document commit, and the four implementation commits described above.
