require "test_helper"

class ApplicationLayoutTest < ActiveSupport::TestCase
  test "article header becomes text only when no cover is attached" do
    layout = ApplicationLayout.new
    layout.page_kind(:article)

    assert_includes layout.send(:article_header_classes), "article-header--text-only"

    layout.cover_image("/images/posts/example.svg", alt: "")

    refute_includes layout.send(:article_header_classes), "article-header--text-only"
  end

  test "blank article metadata renders a single-column article without facts" do
    layout = Class.new(ApplicationLayout) do
      def view_template
        article_page
      end
    end.new
    layout.page_kind(:article)
    layout.page_title("Blank metadata")
    layout.page_metadata(topic: "", publish_at: "")

    document = Nokogiri::HTML5.parse(layout.call)

    assert document.at_css(".article-shell--single")
    assert_nil document.at_css(".article-facts")
  end
end
