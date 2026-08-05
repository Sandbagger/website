require "test_helper"

class ApplicationLayoutTest < ActiveSupport::TestCase
  test "article header becomes text only when no cover is attached" do
    layout = ApplicationLayout.new
    layout.page_kind(:article)

    assert_includes layout.send(:article_header_classes), "article-header--text-only"
  end

  test "article header renders dimensioned cover metadata" do
    layout = article_layout
    cover = Writing::Cover.new(
      src: "/images/posts/example.webp",
      width: 1200,
      height: 630
    )
    layout.page_kind(:article)
    layout.cover_image(cover, alt: "")

    document = Nokogiri::HTML5.fragment(layout.call)
    image = document.at_css("img.article-cover")

    assert_equal "/images/posts/example.webp", image["src"]
    assert_equal "1200", image["width"]
    assert_equal "630", image["height"]
    assert_equal "", image["alt"]

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

  private

  def article_layout
    Class.new(ApplicationLayout) do
      def view_template
        article_page
      end
    end.new
  end
end
