require "test_helper"

class CssArchitectureTest < ActiveSupport::TestCase
  APPLICATION_CSS = Rails.root.join("app/assets/stylesheets/application.css")
  BLOCKS_INDEX = Rails.root.join("app/assets/stylesheets/blocks/index.css")
  SITE_HEADER_CSS = Rails.root.join("app/assets/stylesheets/blocks/site-header.css")
  HOME_CSS = Rails.root.join("app/assets/stylesheets/blocks/home.css")
  WRITING_COLLECTION_CSS = Rails.root.join("app/assets/stylesheets/blocks/writing-collection.css")
  ARTICLE_CSS = Rails.root.join("app/assets/stylesheets/blocks/article.css")
  VARIABLES_CSS = Rails.root.join("app/assets/stylesheets/global/variables.css")
  RESET_CSS = Rails.root.join("app/assets/stylesheets/global/reset.css")
  GLOBAL_STYLES_CSS = Rails.root.join("app/assets/stylesheets/global/styles.css")

  test "application imports each CUBE layer once and in order" do
    imports = File.read(APPLICATION_CSS).scan(/@import url\(["']([^"']+)["']\);/).flatten

    assert_equal [
      "/global/index.css",
      "/compositions/index.css",
      "/utilities/index.css",
      "/blocks/index.css"
    ], imports
  end

  test "blocks import editorial styles in order" do
    imports = File.read(BLOCKS_INDEX).scan(/@import url\(["']([^"']+)["']\);/).flatten

    assert_equal [
      "page.css",
      "site-header.css",
      "home.css",
      "writing-collection.css",
      "article.css",
      "site-footer.css"
    ], imports
  end

  test "site header keeps wordmark inline and navigation spacing composable" do
    styles = File.read(SITE_HEADER_CSS)
    wordmark = styles.match(/\.wordmark\s*\{([^}]*)\}/m)[1]
    navigation = styles.match(/\.site-header nav ul\s*\{([^}]*)\}/m)[1]

    refute_includes wordmark, "display: block;"
    assert_includes navigation, "--space: clamp(0.75rem, 2vw, 1.4rem);"
    refute_match(/^\s*gap:/, navigation)
  end

  test "home scopes display headings to the intro and leaves eyebrow style inherited" do
    styles = File.read(HOME_CSS)
    eyebrow = styles.match(/\.eyebrow\s*\{([^}]*)\}/m)[1]

    assert_match(/^\.home-intro h1\s*\{/m, styles)
    refute_match(/^\.home-hero h1\s*\{/m, styles)
    refute_includes eyebrow, "font-style: normal;"
  end

  test "writing collection uses the approved spacing and selector contracts" do
    styles = File.read(WRITING_COLLECTION_CSS)
    collection_header = styles.match(/\.collection-header\s*\{([^}]*)\}/m)[1]
    cover = styles.match(/\.writing-feature__cover\s*\{([^}]*)\}/m)[1]
    archive_heading = styles.match(/\.writing-collection--archive > h2\s*\{([^}]*)\}/m)[1]

    assert_includes collection_header, "margin-bottom: var(--space-m);"
    assert_includes styles, ".collection-header > a,\n.article-row > a"
    assert_includes styles, "grid-template-columns: minmax(0, 1.45fr) minmax(18rem, 0.75fr);"
    assert_includes cover, "margin-bottom: var(--space-m);"
    refute_includes cover, "margin: 0;"
    assert_includes archive_heading, "margin-bottom: var(--space-m);"
    refute_match(/^\s*margin:/, archive_heading)
  end

  test "article grids and facts use the approved editorial measurements" do
    styles = File.read(ARTICLE_CSS)
    facts_list = styles.match(/\.article-facts dl\s*\{([^}]*)\}/m)[1]
    facts_term = styles.match(/\.article-facts dt\s*\{([^}]*)\}/m)[1]

    assert_includes styles, "grid-template-columns: minmax(0, 1.4fr) minmax(18rem, 0.6fr);"
    assert_match(/\.article-shell\s*\{[^}]*gap: clamp\(2rem, 6vw, 6rem\);/m, styles)
    assert_includes facts_list, "margin: var(--space-xs) 0 0;"
    assert_includes facts_term, "margin-top: var(--space-xs);"
    assert_includes facts_term, "letter-spacing: 0.06em;"
  end

  test "global tokens define the editorial foundation" do
    tokens = File.read(VARIABLES_CSS)

    [
      "--color-paper: #f2eadb",
      "--color-ink: #172c35",
      "--color-coral: #d95136",
      "--color-blush: #e8a7a0",
      "--measure-reading: 68ch",
      "--measure-wide: 75rem"
    ].each { |token| assert_includes tokens, token }
  end

  test "reset does not add body padding" do
    refute_match(/body\s*\{[^}]*padding:/m, File.read(RESET_CSS))
  end

  test "editorial base styles keep link and code treatments precise" do
    styles = File.read(GLOBAL_STYLES_CSS)
    pre_code = styles.match(/pre code\s*\{([^}]*)\}/m)[1]

    refute_match(/^a\s*\{[^}]*text-decoration-style:\s*dashed;/m, styles)
    assert_includes styles, "box-shadow: inset 4px 0 0 var(--color-coral);"
    assert_includes pre_code, "font-size: inherit;"
    refute_includes pre_code, "font: inherit;"
  end
end
