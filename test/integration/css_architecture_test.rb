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
