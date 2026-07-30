require "test_helper"

class ApplicationLayoutTest < ActiveSupport::TestCase
  test "article header becomes text only when no cover is attached" do
    layout = ApplicationLayout.new
    layout.page_kind(:article)

    assert_includes layout.send(:article_header_classes), "article-header--text-only"

    layout.cover_image("/images/posts/example.svg", alt: "")

    refute_includes layout.send(:article_header_classes), "article-header--text-only"
  end
end
