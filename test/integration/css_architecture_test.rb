require "test_helper"

class CssArchitectureTest < ActiveSupport::TestCase
  APPLICATION_CSS = Rails.root.join("app/assets/stylesheets/application.css")
  BLOCKS_INDEX = Rails.root.join("app/assets/stylesheets/blocks/index.css")
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
