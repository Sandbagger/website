# Curious Editorial Site Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers-ruby:subagent-driven-development` (recommended) or `superpowers-ruby:executing-plans` to implement this plan task-by-task. Use `superpowers-ruby:test-driven-development` for every behavior change and `superpowers-ruby:verification-before-completion` before claiming completion. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh williamneal.dev into the approved “Curious Editorial” design while preserving its global → compositions → utilities → blocks CUBE CSS cascade and existing Sitepress publishing workflow.

**Architecture:** The Sitepress controller continues to select and sort published resources, then passes explicit presentation contexts to Phlex. `ApplicationLayout` owns the semantic document shell and selects normal-page or article rendering; focused Phlex components own navigation, footer, and writing collections. CSS remains plain CSS organized by CUBE responsibility, with unique page grids kept at block level.

**Tech Stack:** Rails 8, Ruby 3.3.5, Phlex 2, Sitepress, Markdown-Rails/Redcarpet, Propshaft, plain CSS, Minitest, Capybara/Selenium.

**Approved spec:** `docs/superpowers/specs/2026-07-30-curious-editorial-redesign-design.md`

**Working-tree caution:** Preserve the user-owned untracked `.DS_Store` and `docs/superpowers/plans/2026-07-22-kamal-hatchbox-cutover.md`. Stage only files named by each task.

---

## File Map

### Create

- `app/helpers/post_cover_helper.rb` — one source of truth for resolving optional generated post covers.
- `app/views/components/footer_component.rb` — shared footer and external-profile links.
- `app/assets/stylesheets/blocks/page.css` — shared page-shell rules.
- `app/assets/stylesheets/blocks/site-header.css` — wordmark and primary navigation.
- `app/assets/stylesheets/blocks/home.css` — homepage hero and “Currently exploring.”
- `app/assets/stylesheets/blocks/writing-collection.css` — featured article and compact archive rows.
- `app/assets/stylesheets/blocks/article.css` — article header, facts rail, prose-adjacent layout, and cover.
- `app/assets/stylesheets/blocks/site-footer.css` — shared footer.
- `app/assets/stylesheets/utilities/sr-only.css` — accessible visually hidden content.
- `test/helpers/post_cover_helper_test.rb` — present/missing cover behavior.
- `test/components/collection_component_test.rb` — collection empty and metadata/cover degradation behavior.
- `test/integration/css_architecture_test.rb` — CUBE import contract and asset delivery.
- `test/integration/site_chrome_test.rb` — semantic shell, navigation, footer, and active state.
- `test/integration/page_context_test.rb` — Sitepress layout context routing.
- `test/integration/writing_collection_test.rb` — homepage, archive, and article collection variants.
- `test/integration/article_layout_test.rb` — article header/body/facts/cover semantics.
- `test/views/layouts/application_layout_test.rb` — article cover/no-cover class selection.
- `test/integration/about_page_test.rb` — approved About positioning.
- `test/system/editorial_layout_test.rb` — computed responsive behavior and overflow checks.

### Modify

- `.gitignore` — ignore persisted visual-companion artifacts.
- `app/assets/stylesheets/application.css` — import each CUBE layer once and in order.
- `app/assets/stylesheets/global/fonts.css` — correct the existing local font face.
- `app/assets/stylesheets/global/variables.css` — approved palette, type, spacing, measure, and border tokens.
- `app/assets/stylesheets/global/reset.css` — remove page-level body padding.
- `app/assets/stylesheets/global/styles.css` — base typography, links, code, lists, media, focus, and reduced motion.
- `app/assets/stylesheets/compositions/center.css` — configurable wide and reading measures.
- `app/assets/stylesheets/compositions/box.css` — use the new color and border tokens.
- `app/assets/stylesheets/utilities/active.css` — visible current-page state.
- `app/assets/stylesheets/utilities/lede.css` — approved introductory type treatment.
- `app/assets/stylesheets/utilities/prose.css` — long-form measure and flow.
- `app/assets/stylesheets/utilities/index.css` — import the visually hidden utility.
- `app/assets/stylesheets/blocks/index.css` — ordered block imports.
- `app/content/helpers/page_helper.rb` — add `aria-current` to current-page links.
- `app/controllers/sitepress/site_controller.rb` — explicit home/archive/article/default contexts.
- `app/views/layouts/application_layout.rb` — valid body structure and normal/article rendering.
- `app/views/components/nav_component.rb` — semantic header and primary navigation.
- `app/views/components/collection_component.rb` — context-specific writing presentation.
- `app/views/components/phlex_markdown_component.rb` — stop forcing decorative bullets on all prose lists.
- `app/content/pages/index.html.markerb` — approved homepage introduction and interests.
- `app/content/pages/about.html.markerb` — “Brit in Brussels,” international-relations background, and exploratory positioning.
- `test/integration/writing_latest_list_test.rb` — rename the article-tail expectation to “More writing.”
- `test/application_system_test_case.rb` — use headless Chrome for repeatable layout checks.

---

### Task 1: Lock the CUBE cascade contract

**Files:**

- Create: `test/integration/css_architecture_test.rb`
- Modify: `app/assets/stylesheets/application.css`
- Modify: `.gitignore`

- [ ] **Step 1: Write the failing import-order test**

```ruby
# test/integration/css_architecture_test.rb
require "test_helper"

class CssArchitectureTest < ActiveSupport::TestCase
  APPLICATION_CSS = Rails.root.join("app/assets/stylesheets/application.css")

  test "application imports each CUBE layer once and in order" do
    imports = File.read(APPLICATION_CSS).scan(
      /@import url\(["']([^"']+)["']\);/
    ).flatten

    assert_equal [
      "/global/index.css",
      "/compositions/index.css",
      "/utilities/index.css",
      "/blocks/index.css"
    ], imports
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bin/rails test test/integration/css_architecture_test.rb
```

Expected: FAIL because `application.css` imports individual composition files and imports `flow.css` twice.

- [ ] **Step 3: Replace the manifest with one import per CUBE layer**

```css
/* app/assets/stylesheets/application.css */
@import url("/global/index.css");
@import url("/compositions/index.css");
@import url("/utilities/index.css");
@import url("/blocks/index.css");
```

- [ ] **Step 4: Ignore persisted visual-companion files**

Append to `.gitignore`:

```gitignore

# Local visual-design exploration artifacts.
/.superpowers/
```

Do not add or remove any existing untracked file.

- [ ] **Step 5: Run the test to verify it passes**

Run:

```bash
bin/rails test test/integration/css_architecture_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add .gitignore app/assets/stylesheets/application.css test/integration/css_architecture_test.rb
git commit -m "refactor(css): preserve CUBE layer order"
```

---

### Task 2: Build the semantic shared shell

**Files:**

- Create: `app/views/components/footer_component.rb`
- Create: `test/integration/site_chrome_test.rb`
- Modify: `app/content/helpers/page_helper.rb`
- Modify: `app/views/components/nav_component.rb`
- Modify: `app/views/layouts/application_layout.rb`

- [ ] **Step 1: Write the failing shared-chrome tests**

```ruby
# test/integration/site_chrome_test.rb
require "test_helper"

class SiteChromeTest < ActionDispatch::IntegrationTest
  test "shared chrome lives inside the body with valid landmarks" do
    get root_url

    assert_response :success
    assert_select "body > header.site-header", 1
    assert_select "body > main.site-main", 1
    assert_select "body > footer.site-footer", 1
    assert_select "nav[aria-label='Primary']", 1
    assert_select "nav ul > h1, nav ul > h2, nav ul > h3", 0
    assert_select "nav ul > ul", 0
  end

  test "primary navigation includes home writing and about" do
    get root_url

    assert_select "nav[aria-label='Primary']" do
      assert_select "a[href='/']", text: "Home"
      assert_select "a[href='/writing']", text: "Writing"
      assert_select "a[href='/about']", text: "About"
    end
  end

  test "current page is visible and programmatically identified" do
    get "/about"

    assert_select "nav a.active[aria-current='page'][href='/about']", text: "About"
  end

  test "footer exposes rss and existing social profiles safely" do
    get root_url

    assert_select "footer" do
      assert_select "a[href='/feed']", text: "RSS"
      assert_select "a[href='https://ruby.social/@Sandbagger'][rel~='me'][rel~='noopener'][rel~='noreferrer']", text: "Mastodon"
      assert_select "a[href='https://bsky.app/profile/williamneal.bsky.social'][rel~='me'][rel~='noopener'][rel~='noreferrer']", text: "Bluesky"
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bin/rails test test/integration/site_chrome_test.rb
```

Expected: FAIL because navigation is outside `<body>`, Writing is absent, list nesting is invalid, the footer is absent, and `aria-current` is absent.

- [ ] **Step 3: Add `aria-current` to current Sitepress links**

Replace `link_to_page` in `app/content/helpers/page_helper.rb` with:

```ruby
def link_to_page(page, title_key: "title")
  title = page.data.fetch(title_key, page.request_path)

  if page == current_page
    link_to title, page.request_path,
      class: "active",
      aria: {current: "page"}
  else
    link_to title, page.request_path
  end
end
```

Leave the other helper methods unchanged.

Normalize the remaining string literals in `PageHelper` to double quotes while the file is already being edited, including the defaults in `link_to_if_current` and the `"layouts/#{layout}"` interpolation. This is mechanical formatting only.

- [ ] **Step 4: Replace the navigation with semantic markup**

```ruby
# app/views/components/nav_component.rb
# frozen_string_literal: true

class NavComponent < ApplicationComponent
  include PageHelper

  def view_template
    header(class: "site-header") do
      div(class: "center cluster-around") do
        link_to "William Neal", "/", class: "wordmark",
          aria: {label: "William Neal, home"}

        nav(aria_label: "Primary") do
          ul(class: "cluster", role: "list") do
            navigation_resources.each do |resource|
              li { link_to_page(resource) }
            end
          end
        end
      end
    end
  end

  private

  def navigation_resources
    [
      Sitepress.site.get("/"),
      Sitepress.site.get("/writing"),
      Sitepress.site.get("/about")
    ]
  end
end
```

- [ ] **Step 5: Add the shared footer**

```ruby
# app/views/components/footer_component.rb
# frozen_string_literal: true

class FooterComponent < ApplicationComponent
  def view_template
    footer(class: "site-footer") do
      div(class: "center cluster-around") do
        small { "Engineer, writer, enthusiastic generalist." }

        ul(class: "cluster", role: "list") do
          li { link_to "RSS", "/feed" }
          li { external_link("Mastodon", "https://ruby.social/@Sandbagger") }
          li { external_link("Bluesky", "https://bsky.app/profile/williamneal.bsky.social") }
        end
      end
    end
  end

  private

  def external_link(label, href)
    link_to label, href,
      target: "_blank",
      rel: "noopener noreferrer me"
  end
end
```

- [ ] **Step 6: Put shared chrome inside `<body>`**

In `ApplicationLayout#view_template`:

1. Add `lang: "en"` to `html`.
2. Preserve the existing `<head>` metadata and asset helpers.
3. Remove the inline `.cover` `<style>` element.
4. Normalize all preserved Ruby string literals in this file to double quotes.
5. Render the body in this order:

```ruby
body do
  render NavComponent.new

  main(class: "site-main") do
    div(class: "page-content center flow") do
      if @cover_image
        img(
          src: @cover_image[:src],
          alt: @cover_image[:alt],
          class: "cover"
        )
      end

      h1 { @page_title } if @page_title
      raw @markdown if @markdown
      render_partials
    end
  end

  render FooterComponent.new
end
```

Add:

```ruby
private

def render_partials
  @partials.each { |partial| render partial }
end
```

Do not change the public `markdown`, `cover_image`, `page_title`, or `partial` methods yet.

Keep the method-style layout DSL and document its intentional linter exception:

```ruby
# standard:disable Style/TrivialAccessors
def markdown(md)
  @markdown = md
end

def page_title(title)
  @page_title = title
end
# standard:enable Style/TrivialAccessors
```

- [ ] **Step 7: Run the shared-chrome and smoke tests**

Run:

```bash
bin/rails test test/integration/site_chrome_test.rb test/integration/pages_smoke_test.rb
```

Expected: PASS.

- [ ] **Step 8: Run StandardRB on the Ruby files**

Run:

```bash
bundle exec standardrb app/content/helpers/page_helper.rb app/views/components/nav_component.rb app/views/components/footer_component.rb app/views/layouts/application_layout.rb
```

Expected: no offenses.

- [ ] **Step 9: Commit**

```bash
git add app/content/helpers/page_helper.rb app/views/components/nav_component.rb app/views/components/footer_component.rb app/views/layouts/application_layout.rb test/integration/site_chrome_test.rb
git commit -m "feat(layout): add semantic site chrome"
```

---

### Task 3: Route explicit page contexts and optional covers

**Files:**

- Create: `app/helpers/post_cover_helper.rb`
- Create: `test/helpers/post_cover_helper_test.rb`
- Create: `test/integration/page_context_test.rb`
- Modify: `app/controllers/sitepress/site_controller.rb`
- Modify: `app/views/layouts/application_layout.rb`
- Modify: `app/views/components/collection_component.rb`
- Modify: `app/content/pages/index.html.markerb`

- [ ] **Step 1: Write the failing cover-helper tests**

```ruby
# test/helpers/post_cover_helper_test.rb
require "test_helper"

class PostCoverHelperTest < ActiveSupport::TestCase
  include PostCoverHelper

  Resource = Data.define(:request_path)

  test "returns the public path when a generated cover exists" do
    resource = Resource.new("/writing/pettis-good-tariffs-vs-bad")

    assert_equal(
      "/images/posts/pettis-good-tariffs-vs-bad.svg",
      post_cover_path(resource)
    )
  end

  test "returns nil when a generated cover is absent" do
    resource = Resource.new("/writing/does-not-have-a-cover")

    assert_nil post_cover_path(resource)
  end
end
```

- [ ] **Step 2: Write the failing page-context tests**

```ruby
# test/integration/page_context_test.rb
require "test_helper"

class PageContextTest < ActionDispatch::IntegrationTest
  test "home uses the home context" do
    get root_url
    assert_select "main.page--home", 1
  end

  test "writing index uses the archive context" do
    get "/writing"
    assert_select "main.page--archive", 1
  end

  test "a writing resource uses the article context" do
    get "/writing/pettis-good-tariffs-vs-bad"
    assert_select "main.page--article", 1
  end

  test "about uses the default context" do
    get "/about"
    assert_select "main.page--default", 1
  end
end
```

- [ ] **Step 3: Run both tests to verify they fail**

Run:

```bash
bin/rails test test/helpers/post_cover_helper_test.rb test/integration/page_context_test.rb
```

Expected: ERROR for missing `PostCoverHelper` and FAIL for missing context classes.

- [ ] **Step 4: Implement optional cover resolution**

```ruby
# app/helpers/post_cover_helper.rb
# frozen_string_literal: true

module PostCoverHelper
  def post_cover_path(resource)
    slug = Pathname(resource.request_path.to_s).basename.to_s
    file = Rails.root.join("public/images/posts", "#{slug}.svg")

    "/images/posts/#{slug}.svg" if file.file?
  end
end
```

- [ ] **Step 5: Give `ApplicationLayout` explicit context and metadata**

In `initialize`, add:

```ruby
@page_kind = :default
@page_metadata = {}
```

Add public setters:

```ruby
# Place page_kind inside the existing
# standard:disable Style/TrivialAccessors block.
def page_kind(kind)
  @page_kind = kind.to_sym
end

def page_metadata(topic: nil, publish_at: nil)
  @page_metadata = {topic:, publish_at:}.compact
end
```

Change the main element to:

```ruby
main(class: tokens("site-main", "page--#{@page_kind}")) do
  # existing Task 2 main contents
end
```

- [ ] **Step 6: Let `CollectionComponent` accept a context without changing presentation yet**

```ruby
def initialize(collection, context: :archive)
  @collection = collection || []
  @context = context.to_sym
end
```

Because this file is included in Task 3’s focused lint check, normalize its remaining legacy string literals to double quotes at the same time without changing the legacy presentation; Task 4 replaces that presentation immediately afterward.

- [ ] **Step 7: Add explicit Sitepress layout methods**

Add `include PostCoverHelper` to `Sitepress::SiteController`, replace `default_layout` and `writing_layout`, and add `home_layout`:

```ruby
def default_layout(page)
  article = writing_post?(page)

  ApplicationLayout.new.tap do |layout|
    layout.page_kind(article ? :article : :default)
    layout.page_title(page_title_for(page))
    layout.page_metadata(
      topic: page.data["topic"],
      publish_at: page.data["publish_at"]
    ) if article
    attach_cover(layout, page)
    layout.markdown(render_resource_inline(page))
    layout.partial(
      CollectionComponent.new(published, context: :article)
    ) if article
  end
end

def home_layout(page)
  ApplicationLayout.new.tap do |layout|
    layout.page_kind(:home)
    layout.markdown(render_resource_inline(page))
    layout.partial(
      CollectionComponent.new(published, context: :home)
    )
  end
end

def writing_layout(page)
  ApplicationLayout.new.tap do |layout|
    layout.page_kind(:archive)
    layout.page_title(page_title_for(page))
    layout.markdown(render_resource_inline(page))
    layout.partial(
      CollectionComponent.new(published, context: :archive)
    )
  end
end
```

Add:

```ruby
def page_title_for(page)
  page.data["title"].presence ||
    page.try(:title).presence ||
    page.request_path.titleize
end

def attach_cover(layout, page)
  src = post_cover_path(page)
  layout.cover_image(src, alt: "") if src
end
```

Remove the old `cover_slug_for` method and old `attach_cover`. Leave `published`, `writing_post?`, and rendering methods otherwise unchanged.

- [ ] **Step 8: Route the homepage through `home_layout`**

Change the frontmatter in `app/content/pages/index.html.markerb`:

```yaml
---
title: Home
layout: home
---
```

Leave the existing body in place until Task 4.

- [ ] **Step 9: Run the focused and smoke tests**

Run:

```bash
bin/rails test test/helpers/post_cover_helper_test.rb test/integration/page_context_test.rb test/integration/pages_smoke_test.rb
```

Expected: PASS.

- [ ] **Step 10: Run StandardRB**

Run:

```bash
bundle exec standardrb app/helpers/post_cover_helper.rb app/controllers/sitepress/site_controller.rb app/views/layouts/application_layout.rb app/views/components/collection_component.rb test/helpers/post_cover_helper_test.rb test/integration/page_context_test.rb
```

Expected: no offenses.

- [ ] **Step 11: Commit**

```bash
git add app/helpers/post_cover_helper.rb app/controllers/sitepress/site_controller.rb app/views/layouts/application_layout.rb app/views/components/collection_component.rb app/content/pages/index.html.markerb test/helpers/post_cover_helper_test.rb test/integration/page_context_test.rb
git commit -m "refactor(content): route explicit page contexts"
```

---

### Task 4: Build the homepage and writing collection variants

**Files:**

- Create: `test/components/collection_component_test.rb`
- Create: `test/integration/writing_collection_test.rb`
- Modify: `app/content/pages/index.html.markerb`
- Modify: `app/views/components/collection_component.rb`

- [ ] **Step 1: Write the failing collection tests**

```ruby
# test/integration/writing_collection_test.rb
require "test_helper"

class WritingCollectionTest < ActionDispatch::IntegrationTest
  test "home features the latest resource and limits compact rows to three" do
    get root_url

    assert_response :success
    assert_select "section.writing-collection--home", 1
    assert_select "article.writing-feature", 1 do
      assert_select(
        "a[href='/writing/pettis-good-tariffs-vs-bad']",
        text: /Michael Pettis/
      )
    end
    assert_select ".writing-collection--home .article-row", 3
    assert_select "a[href='/writing']", text: /archive/i
  end

  test "writing archive uses compact rows without a feature" do
    get "/writing"

    assert_response :success
    assert_select "section.writing-collection--archive", 1
    assert_select "section.writing-collection--archive > h2", text: "All writing"
    assert_select "article.writing-feature", 0
    assert_select ".writing-collection--archive .article-row", 4
  end

  test "writing archive is in descending publication order" do
    get "/writing"

    document = Nokogiri::HTML5(response.body)
    paths = document.css(
      ".writing-collection--archive .article-row h3 a"
    ).map { |link| link["href"] }

    assert_equal [
      "/writing/pettis-good-tariffs-vs-bad",
      "/writing/capture-request-referrer-via-css",
      "/writing/tag-overriding-in-phlex-and-markdown",
      "/writing/markdown-in-rails-with-phlex-and-sitepress"
    ], paths
  end

  test "article tail uses more writing and excludes the current resource" do
    path = "/writing/markdown-in-rails-with-phlex-and-sitepress"
    get path

    assert_response :success
    assert_select "section.writing-collection--more", 1
    assert_select "h2", text: "More writing"
    assert_select "a[href='#{path}']", 0
  end
end
```

The archive count is intentionally tied to the four currently published resources. If fixtures change before implementation, compute the expected count from the same published Sitepress collection instead of weakening the assertion.

- [ ] **Step 2: Write failing component degradation tests**

```ruby
# test/components/collection_component_test.rb
require "test_helper"

class CollectionComponentTest < ActiveSupport::TestCase
  Resource = Data.define(:request_path, :data)

  test "home renders a quiet empty state" do
    document = render_component([], context: :home)

    assert_equal "New writing will appear here.",
      document.at_css(".empty-state").text
    assert_nil document.at_css(".writing-feature")
  end

  test "home renders only the compact resources available" do
    document = render_component(
      [
        resource("/writing/does-not-have-a-cover", "Feature"),
        resource("/writing/another-note", "Another")
      ],
      context: :home
    )

    assert document.at_css(".writing-feature")
    assert_equal 1, document.css(".article-row").length
  end

  test "feature becomes text led when its cover is absent" do
    document = render_component(
      [resource("/writing/does-not-have-a-cover", "Text only")],
      context: :home
    )

    assert document.at_css(".writing-feature--text-only")
    assert_nil document.at_css(".writing-feature img")
  end

  test "missing topic and date produce a title link without placeholders" do
    document = render_component(
      [resource("/writing/title-only", "Title only")],
      context: :archive
    )

    assert_equal "Title only", document.at_css(".article-row h3 a").text
    assert_nil document.at_css(".article-row .article-meta")
  end

  private

  def render_component(resources, context:)
    html = CollectionComponent.new(resources, context:).call
    Nokogiri::HTML5.fragment(html)
  end

  def resource(path, title)
    Resource.new(path, {"title" => title})
  end
end
```

- [ ] **Step 3: Run the tests to verify they fail**

Run:

```bash
bin/rails test test/components/collection_component_test.rb test/integration/writing_collection_test.rb
```

Expected: FAIL because all contexts still render the legacy “Latest” bullet list and no degradation behavior exists.

- [ ] **Step 4: Replace the homepage body with the approved content**

```html
---
title: Home
layout: home
---

<section class="home-hero">
  <div class="home-intro">
    <p class="eyebrow">From Brussels, with questions</p>
    <h1>Thinking in systems.</h1>
    <p class="lede">I’m William, a software engineer writing about building software, political economy, and the questions that sit between them.</p>
  </div>

  <aside class="interests" aria-labelledby="interests-heading">
    <h2 class="eyebrow" id="interests-heading">Currently exploring</h2>
    <ul role="list">
      <li>Agentic workflows</li>
      <li>Smaller language models</li>
      <li>European technology</li>
      <li>Macroeconomic imbalances</li>
    </ul>
  </aside>
</section>
```

- [ ] **Step 5: Implement context-specific writing collections**

Replace `CollectionComponent` with:

```ruby
# frozen_string_literal: true

class CollectionComponent < ApplicationComponent
  include PostCoverHelper

  def initialize(collection, context: :archive)
    @collection = collection || []
    @context = context.to_sym
  end

  def view_template
    return if @context == :article && @collection.empty?

    section(class: section_classes) do
      case @context
      when :home then home_collection
      when :article then more_collection
      else archive_collection
      end
    end
  end

  private

  def home_collection
    collection_header("Selected writing")

    if @collection.empty?
      p(class: "empty-state") { "New writing will appear here." }
    else
      feature(@collection.first)
      rows(@collection.drop(1).first(3))
    end
  end

  def archive_collection
    h2 { "All writing" }

    if @collection.empty?
      p(class: "empty-state") { "No published writing yet." }
    else
      rows(@collection)
    end
  end

  def more_collection
    collection_header("More writing")
    rows(@collection)
  end

  def collection_header(title)
    header(class: "collection-header cluster-around") do
      h2 { title }
      a(href: "/writing") { "Everything in the archive →" }
    end
  end

  def feature(resource)
    cover = post_cover_path(resource)

    article(
      class: tokens(
        "writing-feature",
        cover ? nil : "writing-feature--text-only"
      )
    ) do
      if cover
        a(
          href: resource.request_path,
          class: "writing-feature__cover",
          aria_label: "Read #{resource_title(resource)}"
        ) do
          img(src: cover, alt: "")
        end
      end

      resource_metadata(resource)
      h3 do
        a(href: resource.request_path) { resource_title(resource) }
      end
    end
  end

  def rows(resources)
    ol(class: "article-list", role: "list") do
      resources.each do |resource|
        li(class: "article-row") do
          resource_metadata(resource)
          h3 do
            a(href: resource.request_path) { resource_title(resource) }
          end
          a(
            href: resource.request_path,
            aria_label: "Read #{resource_title(resource)}"
          ) { "Read note →" }
        end
      end
    end
  end

  def resource_metadata(resource)
    parts = [
      formatted_topic(resource.data["topic"]),
      formatted_date(resource.data["publish_at"])
    ].compact

    p(class: "article-meta") { parts.join(" · ") } if parts.any?
  end

  def formatted_topic(topic)
    return if topic.blank?

    topic.to_s.split(",").map(&:strip).join(" · ")
  end

  def formatted_date(date)
    date&.strftime("%-d %B %Y")
  end

  def resource_title(resource)
    resource.data.fetch("title", resource.request_path)
  end

  def section_classes
    classes = [
      "writing-collection",
      "writing-collection--#{context_modifier}"
    ]
    classes << "center" if @context == :article
    tokens(*classes)
  end

  def context_modifier
    @context == :article ? "more" : @context
  end
end
```

- [ ] **Step 6: Run collection, homepage, and smoke tests**

Run:

```bash
bin/rails test test/components/collection_component_test.rb test/integration/writing_collection_test.rb test/controllers/homepage_controller_test.rb test/integration/pages_smoke_test.rb
```

Expected: PASS.

- [ ] **Step 7: Run StandardRB**

Run:

```bash
bundle exec standardrb app/views/components/collection_component.rb test/components/collection_component_test.rb test/integration/writing_collection_test.rb
```

Expected: no offenses.

- [ ] **Step 8: Commit**

```bash
git add app/content/pages/index.html.markerb app/views/components/collection_component.rb test/components/collection_component_test.rb test/integration/writing_collection_test.rb
git commit -m "feat(home): feature selected writing"
```

---

### Task 5: Render calm long-form article pages

**Files:**

- Create: `test/views/layouts/application_layout_test.rb`
- Create: `test/integration/article_layout_test.rb`
- Modify: `app/views/layouts/application_layout.rb`
- Modify: `app/views/components/phlex_markdown_component.rb`
- Modify: `test/integration/writing_latest_list_test.rb`

- [ ] **Step 1: Write the failing article-layout tests**

```ruby
# test/integration/article_layout_test.rb
require "test_helper"

class ArticleLayoutTest < ActionDispatch::IntegrationTest
  PATH = "/writing/pettis-good-tariffs-vs-bad"

  test "article header keeps title metadata and decorative cover together" do
    get PATH

    assert_response :success
    assert_select "header.article-header", 1 do
      assert_select "h1", text: "Michael Pettis on Good Tariffs vs Bad"
      assert_select ".article-meta", text: /Macroeconomics/
      assert_select ".article-meta", text: /12 October 2025/
      assert_select "img.article-cover[alt='']", 1
    end
  end

  test "article body uses a facts rail and prose column" do
    get PATH

    assert_select ".article-shell", 1 do
      assert_select "aside.article-facts", 1
      assert_select "article.prose", 1
      assert_select "article.prose h2", minimum: 1
    end
  end

  test "introductory markdown remains in the article body" do
    get PATH

    assert_select "header.article-header > p", 0
    assert_select "article.prose", text: /prompted me to write this/
  end
end
```

- [ ] **Step 2: Write the failing no-cover class test**

```ruby
# test/views/layouts/application_layout_test.rb
require "test_helper"

class ApplicationLayoutTest < ActiveSupport::TestCase
  test "article header becomes text only when no cover is attached" do
    layout = ApplicationLayout.new
    layout.page_kind(:article)

    assert_includes(
      layout.send(:article_header_classes),
      "article-header--text-only"
    )

    layout.cover_image("/images/posts/example.svg", alt: "")

    refute_includes(
      layout.send(:article_header_classes),
      "article-header--text-only"
    )
  end
end
```

- [ ] **Step 3: Update the legacy article-tail test**

Change the assertion in `test/integration/writing_latest_list_test.rb` from:

```ruby
assert_includes @response.body, "Latest"
```

to:

```ruby
assert_includes @response.body, "More writing"
```

Keep the current-article exclusion assertion unchanged.

- [ ] **Step 4: Run the focused tests to verify they fail**

Run:

```bash
bin/rails test test/views/layouts/application_layout_test.rb test/integration/article_layout_test.rb test/integration/writing_latest_list_test.rb
```

Expected: FAIL because article content still uses the generic page shell.

- [ ] **Step 5: Split normal and article rendering in `ApplicationLayout`**

Inside `main`, replace the Task 2 generic content with:

```ruby
if article?
  article_page
else
  standard_page
end
```

Add these private methods:

```ruby
def article?
  @page_kind == :article
end

def standard_page
  div(class: "page-content center flow") do
    h1 { @page_title } if @page_title
    raw @markdown if @markdown
    render_partials
  end
end

def article_page
  header(class: article_header_classes) do
    div do
      article_metadata
      h1 { @page_title }
    end

    if @cover_image
      figure(class: "article-cover-frame") do
        img(
          src: @cover_image[:src],
          alt: @cover_image[:alt],
          class: "article-cover"
        )
      end
    end
  end

  div(
    class: tokens(
      "article-shell",
      "center",
      @page_metadata.any? ? nil : "article-shell--single"
    )
  ) do
    article_facts if @page_metadata.any?
    article(class: "prose flow") { raw @markdown if @markdown }
  end

  render_partials
end

def article_metadata
  parts = [
    formatted_topic,
    formatted_publish_date
  ].compact

  p(class: "article-meta") { parts.join(" · ") } if parts.any?
end

def article_header_classes
  tokens(
    "article-header",
    "center",
    @cover_image ? nil : "article-header--text-only"
  )
end

def article_facts
  aside(class: "article-facts") do
    span(class: "eyebrow") { "Filed under" }
    dl do
      fact("Topics", formatted_topic)
      fact("Published", formatted_publish_date)
    end
  end
end

def fact(label, value)
  return if value.blank?

  dt { label }
  dd { value }
end

def formatted_topic
  topic = @page_metadata[:topic]
  return if topic.blank?

  topic.to_s.split(",").map(&:strip).join(" · ")
end

def formatted_publish_date
  @page_metadata[:publish_at]&.strftime("%-d %B %Y")
end
```

Keep `render_partials` as the single partial-rendering method. Do not create lede extraction or reading-time logic.

- [ ] **Step 6: Stop forcing decorative bullets into Markdown prose**

In `app/views/components/phlex_markdown_component.rb`, remove:

```ruby
def ul
  super(class: "bullet")
end
```

Keep the wrapping `div(class: "flow")`.

- [ ] **Step 7: Run article, collection, and smoke tests**

Run:

```bash
bin/rails test test/views/layouts/application_layout_test.rb test/integration/article_layout_test.rb test/integration/writing_latest_list_test.rb test/integration/writing_collection_test.rb test/integration/pages_smoke_test.rb
```

Expected: PASS.

- [ ] **Step 8: Run StandardRB**

Run:

```bash
bundle exec standardrb app/views/layouts/application_layout.rb app/views/components/phlex_markdown_component.rb test/views/layouts/application_layout_test.rb test/integration/article_layout_test.rb test/integration/writing_latest_list_test.rb
```

Expected: no offenses.

- [ ] **Step 9: Commit**

```bash
git add app/views/layouts/application_layout.rb app/views/components/phlex_markdown_component.rb test/views/layouts/application_layout_test.rb test/integration/article_layout_test.rb test/integration/writing_latest_list_test.rb
git commit -m "feat(writing): add editorial article layout"
```

---

### Task 6: Update the About positioning

**Files:**

- Create: `test/integration/about_page_test.rb`
- Modify: `app/content/pages/about.html.markerb`

- [ ] **Step 1: Write the failing About-page test**

```ruby
# test/integration/about_page_test.rb
require "test_helper"

class AboutPageTest < ActionDispatch::IntegrationTest
  test "about connects existing identity to the emerging direction" do
    get "/about"

    assert_response :success
    assert_select "h1", text: "About"
    assert_includes response.body, "Brit in Brussels"
    assert_includes response.body, "master"
    assert_includes response.body, "international relations"
    assert_includes response.body, "agentic"
    assert_includes response.body, "European technology"
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bin/rails test test/integration/about_page_test.rb
```

Expected: FAIL because the current copy does not mention the degree or emerging direction.

- [ ] **Step 3: Replace the About copy**

```markdown
---
title: About
---

Brit in Brussels 🇬🇧🇪🇺. I’m a software engineer with a master’s degree in international relations.

I’m currently exploring practical agentic workflows with smaller language models, and beginning to write about political economy, macroeconomics, and European technology.

Between changing nappies, not learning French, and being woken at strange hours, I make time to think, learn, and write.
```

This preserves the user-approved phrase and personal cadence while removing the outdated “next job was cyber” aside.

- [ ] **Step 4: Run the test and page smoke test**

Run:

```bash
bin/rails test test/integration/about_page_test.rb test/integration/pages_smoke_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/content/pages/about.html.markerb test/integration/about_page_test.rb
git commit -m "feat(about): clarify interdisciplinary direction"
```

---

### Task 7: Establish the global visual foundation

**Files:**

- Modify: `test/integration/css_architecture_test.rb`
- Modify: `app/assets/stylesheets/global/fonts.css`
- Modify: `app/assets/stylesheets/global/variables.css`
- Modify: `app/assets/stylesheets/global/reset.css`
- Modify: `app/assets/stylesheets/global/styles.css`
- Modify: `app/assets/stylesheets/compositions/center.css`
- Modify: `app/assets/stylesheets/compositions/box.css`
- Modify: `app/assets/stylesheets/utilities/active.css`
- Modify: `app/assets/stylesheets/utilities/index.css`
- Modify: `app/assets/stylesheets/utilities/lede.css`
- Modify: `app/assets/stylesheets/utilities/prose.css`
- Create: `app/assets/stylesheets/utilities/sr-only.css`

- [ ] **Step 1: Extend the CSS contract test**

Add to `CssArchitectureTest`:

```ruby
VARIABLES_CSS = Rails.root.join(
  "app/assets/stylesheets/global/variables.css"
)
RESET_CSS = Rails.root.join("app/assets/stylesheets/global/reset.css")

test "global tokens contain the approved curious editorial palette" do
  css = File.read(VARIABLES_CSS)

  assert_includes css, "--color-paper: #f2eadb"
  assert_includes css, "--color-ink: #172c35"
  assert_includes css, "--color-coral: #d95136"
  assert_includes css, "--color-blush: #e8a7a0"
  assert_includes css, "--measure-reading: 68ch"
  assert_includes css, "--measure-wide: 75rem"
end

test "reset does not impose page layout padding on body" do
  refute_match(/body\s*\{[^}]*padding:/m, File.read(RESET_CSS))
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bin/rails test test/integration/css_architecture_test.rb
```

Expected: FAIL for missing tokens and legacy body padding.

- [ ] **Step 3: Correct the local Space Mono face**

```css
/* app/assets/stylesheets/global/fonts.css */
@font-face {
  font-family: "Space Mono";
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url("/SpaceMono-Regular.ttf") format("truetype");
}
```

- [ ] **Step 4: Replace global tokens**

```css
/* app/assets/stylesheets/global/variables.css */
:root {
  --color-paper: #f2eadb;
  --color-paper-deep: #e7dcc8;
  --color-ink: #172c35;
  --color-coral: #d95136;
  --color-blush: #e8a7a0;

  --color-light: var(--color-paper);
  --color-dark: var(--color-ink);
  --color-primary: var(--color-coral);

  --font-display: ui-serif, Georgia, "Times New Roman", serif;
  --font-body: ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  --font-mono: "Space Mono", ui-monospace, SFMono-Regular, Consolas, monospace;

  --size-step--1: clamp(0.78rem, 0.75rem + 0.12vw, 0.86rem);
  --size-step-0: clamp(1rem, 0.96rem + 0.18vw, 1.12rem);
  --size-step-1: clamp(1.2rem, 1.05rem + 0.6vw, 1.55rem);
  --size-step-2: clamp(1.75rem, 1.45rem + 1.2vw, 2.65rem);
  --size-step-3: clamp(2.2rem, 1.7rem + 2.2vw, 4rem);
  --size-step-4: clamp(3.2rem, 2rem + 5vw, 7.4rem);

  --space-2xs: 0.35rem;
  --space-xs: 0.65rem;
  --space-s: 1rem;
  --space-m: 1.5rem;
  --space-l: clamp(2rem, 4vw, 3.5rem);
  --space-xl: clamp(3.5rem, 8vw, 7rem);

  --gutter: clamp(1.1rem, 4vw, 3rem);
  --measure-reading: 68ch;
  --measure-wide: 75rem;
  --border-thin: 1px;
  --border-strong: 3px;

  --ratio: 1.5;
  --s0: 1rem;
  --s1: calc(var(--s0) / var(--ratio));
  --s2: calc(var(--s1) * var(--ratio));
}
```

- [ ] **Step 5: Remove body padding from the reset**

Retain the existing reset rules, but change its body rule to:

```css
body {
  min-height: 100vh;
  text-rendering: optimizeLegibility;
}
```

Ensure the declaration ends with a semicolon.

- [ ] **Step 6: Replace base element styling**

```css
/* app/assets/stylesheets/global/styles.css */
body {
  display: flex;
  flex-direction: column;
  background: var(--color-paper);
  color: var(--color-ink);
  font-family: var(--font-body);
  font-size: var(--size-step-0);
  line-height: 1.65;
}

h1,
h2,
h3 {
  font-family: var(--font-display);
  font-weight: 500;
  letter-spacing: -0.035em;
  line-height: 1.05;
}

h1 { font-size: var(--size-step-3); }
h2 { font-size: var(--size-step-2); }
h3 { font-size: var(--size-step-1); }

a {
  color: currentColor;
  text-decoration-color: var(--color-coral);
  text-decoration-thickness: 2px;
  text-underline-offset: 0.22em;
}

a:hover {
  text-decoration-style: solid;
}

a:focus-visible {
  outline: 3px solid var(--color-coral);
  outline-offset: 4px;
}

p { max-width: var(--measure-reading); }

ul,
ol {
  padding-inline-start: 1.25em;
}

img,
picture,
svg {
  max-width: 100%;
  height: auto;
}

blockquote {
  margin-inline: 0;
  padding: var(--space-m);
  border: 0;
  background: var(--color-paper-deep);
  box-shadow: inset 4px 0 0 var(--color-coral);
  font-family: var(--font-display);
  font-size: 1.12em;
  font-style: italic;
  line-height: 1.5;
}

pre {
  max-width: 100%;
  overflow-x: auto;
  padding: var(--space-m);
  border: var(--border-thin) solid var(--color-ink);
  background: var(--color-paper-deep);
  font-family: var(--font-mono);
  font-size: 0.88em;
  line-height: 1.6;
}

code {
  padding-inline: 0.2em;
  background: var(--color-paper-deep);
  font-family: var(--font-mono);
  font-size: 0.9em;
}

pre code {
  padding: 0;
  background: transparent;
  font-size: inherit;
}
```

Keep the existing reduced-motion media query in `reset.css`; do not duplicate it.

- [ ] **Step 7: Make the center composition configurable**

```css
/* app/assets/stylesheets/compositions/center.css */
.center {
  width: min(
    calc(100% - (2 * var(--gutter))),
    var(--measure, var(--measure-wide))
  );
  margin-inline: auto;
}
```

Update `box.css` to use `var(--border-thin)`, `var(--color-paper)`, and `var(--color-ink)` without changing its public classes.

- [ ] **Step 8: Update the focused utilities**

Add `@import url("sr-only.css");` to `app/assets/stylesheets/utilities/index.css` after the existing utility imports, then create:

```css
/* utilities/sr-only.css */
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}
```

```css
/* utilities/active.css */
.active {
  text-decoration-color: var(--color-coral);
  text-decoration-style: solid;
  text-decoration-thickness: 3px;
}
```

```css
/* utilities/lede.css */
.lede {
  max-width: 44ch;
  font-family: var(--font-display);
  font-size: var(--size-step-1);
  line-height: 1.45;
}

.lede + * {
  --flow-space: var(--space-l);
}
```

```css
/* utilities/prose.css */
.prose {
  --flow-space: 1.25em;
  min-width: 0;
  max-width: var(--measure-reading);
}

.prose :is(h2, h3) {
  --flow-space: 2.2em;
}

.prose :is(h2, h3) + * {
  --flow-space: 0.65em;
}

.prose h2::before {
  content: "§ ";
  color: var(--color-coral);
}

.prose :is(a, code) {
  overflow-wrap: anywhere;
}
```

- [ ] **Step 9: Run CSS contract and all integration tests**

Run:

```bash
bin/rails test test/integration/css_architecture_test.rb test/integration
```

Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add app/assets/stylesheets/global app/assets/stylesheets/compositions/center.css app/assets/stylesheets/compositions/box.css app/assets/stylesheets/utilities test/integration/css_architecture_test.rb
git commit -m "feat(css): establish curious editorial foundation"
```

---

### Task 8: Style the approved blocks and verify responsive behavior

**Files:**

- Create: `app/assets/stylesheets/blocks/page.css`
- Create: `app/assets/stylesheets/blocks/site-header.css`
- Create: `app/assets/stylesheets/blocks/home.css`
- Create: `app/assets/stylesheets/blocks/writing-collection.css`
- Create: `app/assets/stylesheets/blocks/article.css`
- Create: `app/assets/stylesheets/blocks/site-footer.css`
- Create: `test/system/editorial_layout_test.rb`
- Modify: `app/assets/stylesheets/blocks/index.css`
- Modify: `test/integration/css_architecture_test.rb`
- Modify: `test/application_system_test_case.rb`

- [ ] **Step 1: Add the failing block-import contract**

Add to `CssArchitectureTest`:

```ruby
BLOCKS_INDEX = Rails.root.join("app/assets/stylesheets/blocks/index.css")

test "block index imports the approved interface regions" do
  imports = File.read(BLOCKS_INDEX).scan(
    /@import url\(["']([^"']+)["']\);/
  ).flatten

  assert_equal [
    "page.css",
    "site-header.css",
    "home.css",
    "writing-collection.css",
    "article.css",
    "site-footer.css"
  ], imports
end
```

- [ ] **Step 2: Add the failing responsive system test**

Change `test/application_system_test_case.rb`:

```ruby
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
end
```

Create:

```ruby
# test/system/editorial_layout_test.rb
require "application_system_test_case"

class EditorialLayoutTest < ApplicationSystemTestCase
  test "homepage switches from editorial grid to one column" do
    visit "/"

    assert_equal "rgb(242, 234, 219)", page.evaluate_script(
      "getComputedStyle(document.body).backgroundColor"
    )
    assert_operator grid_column_count(".home-hero"), :>, 1

    page.current_window.resize_to(375, 900)

    assert_equal 1, grid_column_count(".home-hero")
    assert_equal 1, grid_column_count(".writing-collection--home")
    assert_no_horizontal_overflow
  end

  test "article facts rail disappears on a narrow screen" do
    visit "/writing/pettis-good-tariffs-vs-bad"

    assert_not_equal "none", display_value(".article-facts")

    page.current_window.resize_to(375, 900)

    assert_equal "none", display_value(".article-facts")
    assert_no_horizontal_overflow
  end

  test "text-only article fallback uses one readable column" do
    visit "/writing/pettis-good-tariffs-vs-bad"

    page.execute_script(<<~JAVASCRIPT)
      document.querySelector(".article-cover-frame").remove()
      document.querySelector(".article-header")
        .classList.add("article-header--text-only")
    JAVASCRIPT

    assert_equal 1, grid_column_count(".article-header")
    assert_no_horizontal_overflow
  end

  private

  def grid_column_count(selector)
    page.evaluate_script(<<~JAVASCRIPT)
      getComputedStyle(document.querySelector("#{selector}"))
        .gridTemplateColumns
        .split(" ")
        .length
    JAVASCRIPT
  end

  def display_value(selector)
    page.evaluate_script(
      "getComputedStyle(document.querySelector('#{selector}')).display"
    )
  end

  def assert_no_horizontal_overflow
    scroll_width, viewport_width = page.evaluate_script(<<~JAVASCRIPT)
      [document.documentElement.scrollWidth, window.innerWidth]
    JAVASCRIPT

    assert_operator scroll_width, :<=, viewport_width
  end
end
```

- [ ] **Step 3: Run the focused tests to verify they fail**

Run:

```bash
bin/rails test test/integration/css_architecture_test.rb
bin/rails test:system test/system/editorial_layout_test.rb
```

Expected: the import test FAILS because the files are absent; the system test FAILS on missing palette and responsive layout.

- [ ] **Step 4: Make `blocks/index.css` an ordered manifest**

```css
@import url("page.css");
@import url("site-header.css");
@import url("home.css");
@import url("writing-collection.css");
@import url("article.css");
@import url("site-footer.css");
```

- [ ] **Step 5: Add page and shared-chrome blocks**

```css
/* blocks/page.css */
.site-main {
  flex: 1;
}

.page-content {
  --measure: var(--measure-reading);
  padding-block: var(--space-xl);
}

.page--home .page-content,
.page--archive .page-content {
  --measure: var(--measure-wide);
}

.page--default .page-content > h1,
.page--archive .page-content > h1 {
  margin-bottom: var(--space-l);
}
```

```css
/* blocks/site-header.css */
.site-header {
  border-bottom: var(--border-strong) solid var(--color-ink);
}

.site-header > .center {
  min-height: 4.5rem;
  padding-block: var(--space-s);
}

.wordmark {
  font-family: var(--font-display);
  font-size: var(--size-step-1);
  font-weight: 700;
  letter-spacing: -0.03em;
  text-decoration: none;
}

.site-header nav ul {
  --space: clamp(0.75rem, 2vw, 1.4rem);
  margin: 0;
  padding: 0;
  font-family: var(--font-mono);
  font-size: var(--size-step--1);
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.site-header nav a {
  text-decoration: none;
}

.site-header nav a.active {
  padding-bottom: 0.2rem;
  border-bottom: 3px solid var(--color-coral);
}
```

- [ ] **Step 6: Add the homepage block**

```css
/* blocks/home.css */
.home-hero {
  position: relative;
  display: grid;
  grid-template-columns: minmax(0, 1.35fr) minmax(16rem, 0.65fr);
  gap: clamp(2rem, 6vw, 6rem);
  align-items: end;
  padding-block: clamp(4.5rem, 10vw, 8rem);
}

.home-hero::after {
  position: absolute;
  top: 18%;
  right: 3%;
  content: "✦";
  color: var(--color-coral);
  font-size: clamp(2.4rem, 5vw, 4.7rem);
  line-height: 1;
  transform: rotate(10deg);
}

.home-intro h1 {
  max-width: 12ch;
  margin-block: var(--space-s) var(--space-m);
  font-size: var(--size-step-4);
  letter-spacing: -0.055em;
  line-height: 0.9;
}

.eyebrow {
  display: inline-block;
  width: fit-content;
  margin: 0;
  padding: 0.22rem 0.45rem;
  background: var(--color-blush);
  font-family: var(--font-mono);
  font-size: var(--size-step--1);
  font-weight: 400;
  letter-spacing: 0.07em;
  line-height: 1.25;
  text-transform: uppercase;
  transform: rotate(-1deg);
}

.interests {
  padding-top: var(--space-s);
  border-top: 2px solid var(--color-ink);
}

.interests ul {
  margin: var(--space-s) 0 0;
  padding: 0;
}

.interests li {
  padding-block: var(--space-xs);
  border-bottom: var(--border-thin) solid var(--color-ink);
  font-family: var(--font-display);
  font-size: 1.12rem;
}

@media (max-width: 48rem) {
  .home-hero {
    grid-template-columns: 1fr;
    padding-block: var(--space-xl);
  }

  .home-hero::after {
    top: 2rem;
  }

  .interests {
    width: min(100%, 28rem);
  }
}
```

- [ ] **Step 7: Add the writing collection block**

```css
/* blocks/writing-collection.css */
.writing-collection {
  --measure: var(--measure-wide);
  padding-block: var(--space-l) var(--space-xl);
  border-top: var(--border-strong) solid var(--color-ink);
}

.collection-header {
  margin-bottom: var(--space-m);
}

.collection-header h2 {
  margin: 0;
  font-size: var(--size-step-3);
}

.collection-header > a,
.article-row > a {
  font-family: var(--font-mono);
  font-size: var(--size-step--1);
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.writing-collection--home {
  display: grid;
  grid-template-columns: minmax(0, 1.45fr) minmax(18rem, 0.75fr);
  gap: var(--space-l);
}

.writing-collection--home .collection-header {
  grid-column: 1 / -1;
}

.writing-feature__cover {
  display: block;
  overflow: hidden;
  margin-bottom: var(--space-m);
  border: 2px solid var(--color-ink);
}

.writing-feature__cover img {
  display: block;
  width: 100%;
  aspect-ratio: 16 / 9;
  object-fit: cover;
}

.writing-feature h3 {
  max-width: 19ch;
  margin-block: var(--space-xs) 0;
  font-size: var(--size-step-2);
}

.writing-feature--text-only {
  padding: var(--space-l);
  border: 2px solid var(--color-ink);
}

.writing-feature h3 a,
.article-row h3 a {
  text-decoration: none;
}

.article-meta {
  margin: 0;
  font-family: var(--font-mono);
  font-size: var(--size-step--1);
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.article-list {
  margin: 0;
  padding: 0;
  border-top: 2px solid var(--color-ink);
}

.article-row {
  padding-block: var(--space-s) var(--space-m);
  border-bottom: 2px solid var(--color-ink);
}

.article-row h3 {
  margin-block: var(--space-xs);
}

.writing-collection--archive .article-list {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0 var(--space-l);
}

.writing-collection--archive > h2 {
  margin-bottom: var(--space-m);
  font-size: var(--size-step-3);
}

.writing-collection--more {
  margin-top: var(--space-xl);
}

@media (max-width: 48rem) {
  .writing-collection--home,
  .writing-collection--archive .article-list {
    grid-template-columns: 1fr;
  }
}
```

- [ ] **Step 8: Add the article block**

```css
/* blocks/article.css */
.article-header {
  --measure: var(--measure-wide);
  display: grid;
  grid-template-columns: minmax(0, 1.4fr) minmax(18rem, 0.6fr);
  gap: clamp(2rem, 6vw, 6rem);
  align-items: end;
  padding-block: var(--space-xl);
}

.article-header h1 {
  max-width: 14ch;
  margin-block: var(--space-xs) 0;
  font-size: clamp(3rem, 7vw, 6.5rem);
  letter-spacing: -0.055em;
  line-height: 0.93;
}

.article-header--text-only {
  grid-template-columns: minmax(0, var(--measure-reading));
}

.article-cover-frame {
  overflow: hidden;
  margin: 0;
  border: 2px solid var(--color-ink);
  box-shadow: 9px 9px 0 var(--color-blush);
  transform: rotate(1deg);
}

.article-cover {
  display: block;
  width: 100%;
  aspect-ratio: 4 / 3;
  object-fit: cover;
}

.article-shell {
  --measure: var(--measure-wide);
  display: grid;
  grid-template-columns: minmax(10rem, 0.35fr) minmax(0, 1fr);
  gap: clamp(2rem, 6vw, 6rem);
  padding-block: var(--space-xl);
  border-top: var(--border-strong) solid var(--color-ink);
}

.article-shell--single {
  grid-template-columns: minmax(0, var(--measure-reading));
  justify-content: center;
}

.article-facts {
  align-self: start;
  padding-top: var(--space-xs);
  border-top: 2px solid var(--color-coral);
}

.article-facts dl {
  margin: var(--space-xs) 0 0;
}

.article-facts dt {
  margin-top: var(--space-xs);
  font-family: var(--font-mono);
  font-size: var(--size-step--1);
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.article-facts dd {
  margin: 0;
  font-family: var(--font-display);
  line-height: 1.4;
}

@media (max-width: 48rem) {
  .article-header,
  .article-shell {
    grid-template-columns: 1fr;
  }

  .article-cover-frame {
    width: min(100%, 36rem);
    box-shadow: 6px 6px 0 var(--color-blush);
    transform: none;
  }

  .article-facts {
    display: none;
  }
}
```

- [ ] **Step 9: Add the footer block**

```css
/* blocks/site-footer.css */
.site-footer {
  border-top: var(--border-strong) solid var(--color-ink);
}

.site-footer > .center {
  min-height: 5rem;
  padding-block: var(--space-m);
}

.site-footer :is(small, ul) {
  margin: 0;
  padding: 0;
  font-family: var(--font-mono);
  font-size: var(--size-step--1);
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
```

- [ ] **Step 10: Run the CSS contract and responsive system tests**

Run:

```bash
bin/rails test test/integration/css_architecture_test.rb
bin/rails test:system test/system/editorial_layout_test.rb
```

Expected: PASS. If headless Chrome is unavailable, install nothing without approval; report the environment blocker and still run integration verification.

- [ ] **Step 11: Run the full Rails test suite**

Run:

```bash
bin/rails test
```

Expected: PASS.

- [ ] **Step 12: Commit**

```bash
git add app/assets/stylesheets/blocks test/integration/css_architecture_test.rb test/application_system_test_case.rb test/system/editorial_layout_test.rb
git commit -m "feat(css): style curious editorial pages"
```

---

### Task 9: Final verification and visual QA

**Files:**

- Modify only if verification exposes a defect in an already named implementation file.

- [ ] **Step 1: Build JavaScript assets**

Run:

```bash
yarn build
```

Expected: esbuild completes without errors.

- [ ] **Step 2: Run the complete automated verification set**

Run:

```bash
bin/rails test
bin/rails test:system
bundle exec standardrb \
  app/content/helpers/page_helper.rb \
  app/controllers/sitepress/site_controller.rb \
  app/helpers/post_cover_helper.rb \
  app/views/layouts/application_layout.rb \
  app/views/components/nav_component.rb \
  app/views/components/footer_component.rb \
  app/views/components/collection_component.rb \
  app/views/components/phlex_markdown_component.rb \
  test/application_system_test_case.rb \
  test/components/collection_component_test.rb \
  test/helpers/post_cover_helper_test.rb \
  test/integration/css_architecture_test.rb \
  test/integration/site_chrome_test.rb \
  test/integration/page_context_test.rb \
  test/integration/writing_collection_test.rb \
  test/integration/article_layout_test.rb \
  test/integration/about_page_test.rb \
  test/integration/writing_latest_list_test.rb \
  test/system/editorial_layout_test.rb \
  test/views/layouts/application_layout_test.rb
```

Expected: all commands exit 0. Repository-wide StandardRB has unrelated pre-existing offenses outside these files; do not broaden this redesign into legacy lint cleanup.

- [ ] **Step 3: Verify the compiled stylesheet resolves through Propshaft**

Start the app:

```bash
bin/rails server -p 3000
```

In another shell, request the homepage, the application manifest, and the imported token stylesheet:

```bash
curl --silent --show-error --fail http://127.0.0.1:3000/
curl --silent --show-error --fail http://127.0.0.1:3000/assets/application.css
curl --silent --show-error --fail http://127.0.0.1:3000/assets/global/variables.css
```

Expected: all requests return HTTP 200. The application stylesheet contains its rewritten layer imports, and `/assets/global/variables.css` contains `--color-paper: #f2eadb`.

- [ ] **Step 4: Inspect representative pages at desktop and phone widths**

Check:

- `/`
- `/writing`
- `/about`
- `/writing/pettis-good-tariffs-vs-bad`
- The no-cover article header fallback by removing `.article-cover-frame` and adding `.article-header--text-only` in browser developer tools, matching the repeatable system-test simulation without deleting a real asset.

At approximately 1400px and 375px, confirm:

- Navigation wraps without overlap.
- Homepage hero and writing feature become one column.
- Long titles and code do not create horizontal page overflow.
- Article facts are visible on desktop and absent on phone.
- Focus indication is visible.
- The cover is decorative beside the visible article title.
- “More writing” excludes the current article.

Use the in-app browser if available. Do not substitute unrelated browser automation if that surface is unavailable; rely on the system test plus rendered HTML/CSS inspection and state the limitation.

- [ ] **Step 5: Review the working tree and scope**

Run:

```bash
git status --short
git diff --check
git log --oneline -10
```

Expected:

- Only intentional redesign changes or pre-existing untracked user files remain.
- No `.superpowers/` files are staged.
- No whitespace errors.
- Each task has its focused commit.

- [ ] **Step 6: Handle any verification defect in its owning task**

If verification exposes a defect, return to the task that owns the affected file, add a failing regression test there, make the minimal fix, commit only that task’s named files with a descriptive `fix:` commit, and rerun Steps 1–5 completely. If no defect is found, create no verification-only commit.
