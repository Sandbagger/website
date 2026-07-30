require "test_helper"

class CssArchitectureTest < ActiveSupport::TestCase
  APPLICATION_CSS = Rails.root.join("app/assets/stylesheets/application.css")
  VARIABLES_CSS = Rails.root.join("app/assets/stylesheets/global/variables.css")
  RESET_CSS = Rails.root.join("app/assets/stylesheets/global/reset.css")

  test "application imports each CUBE layer once and in order" do
    imports = File.read(APPLICATION_CSS).scan(/@import url\(["']([^"']+)["']\);/).flatten

    assert_equal [
      "/global/index.css",
      "/compositions/index.css",
      "/utilities/index.css",
      "/blocks/index.css"
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
end
