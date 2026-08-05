require "test_helper"

class ApplicationMarkdownTest < ActiveSupport::TestCase
  test "falls back to escaped alt text when an image link is not a valid URI" do
    markdown = "![Layout](<%= asset_path('layout-in-dev-tools') %>)"

    html = begin
      ApplicationMarkdown.new.renderer.render(markdown)
    rescue => error
      flunk "expected Markdown rendering to tolerate the image link: #{error.message}"
    end

    assert_equal "<p>Layout</p>\n", html
  end
end
