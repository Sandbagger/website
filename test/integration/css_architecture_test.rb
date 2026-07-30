require "test_helper"

class CssArchitectureTest < ActiveSupport::TestCase
  APPLICATION_CSS = Rails.root.join("app/assets/stylesheets/application.css")

  test "application imports each CUBE layer once and in order" do
    expected = <<~CSS
      @import url("/global/index.css");
      @import url("/compositions/index.css");
      @import url("/utilities/index.css");
      @import url("/blocks/index.css");
    CSS

    assert_equal expected, File.read(APPLICATION_CSS)
  end
end
