require "test_helper"

class ApplicationLayoutTest < ActiveSupport::TestCase
  test "article header becomes text only when no cover is attached" do
    layout = ApplicationLayout.new
    layout.page_kind(:article)

    assert_includes layout.send(:article_header_classes), "article-header--text-only"
  end

  test "article header renders dimensioned cover metadata" do
    layout = article_layout
    variants = Writing::Cover::SIZES.map do |width, height|
      Writing::Cover::Variant.new(
        src: "/images/posts/pettis-good-tariffs-vs-bad-#{width}w.webp",
        width: width,
        height: height
      )
    end
    cover = Writing::Cover.new(variants: variants)
    layout.page_kind(:article)
    layout.cover_image(cover, alt: "")

    document = Nokogiri::HTML5.fragment(layout.call)
    image = document.at_css("img.article-cover")

    assert_equal "/images/posts/pettis-good-tariffs-vs-bad-1200w.webp", image["src"]
    assert_equal cover.srcset, image["srcset"]
    assert_equal "(max-width: 48rem) min(calc(100vw - clamp(2.2rem, 8vw, 6rem)), 36rem), 22rem", image["sizes"]
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
    layout.page_metadata(topics: [], publication_date: "")

    document = Nokogiri::HTML5.parse(layout.call)

    assert document.at_css(".article-shell--single")
    assert_nil document.at_css(".article-facts")
  end

  test "article metadata renders linked topics in authored order" do
    layout = article_layout
    layout.page_kind(:article)
    layout.page_title("Topics")
    layout.page_metadata(
      topics: [Writing::Topic.new(label: "Ruby"), Writing::Topic.new(label: "Phlex")]
    )

    document = Nokogiri::HTML5.parse(layout.call)

    assert_equal "Ruby · Phlex", document.at_css(".article-meta").text
    assert_equal "Ruby · Phlex", document.at_css(".article-facts dd").text
    assert_equal ["/writing/topics/ruby", "/writing/topics/phlex"],
      document.css(".article-meta a").map { |link| link["href"] }
    assert_equal ["/writing/topics/ruby", "/writing/topics/phlex"],
      document.css(".article-facts dd a").map { |link| link["href"] }
  end

  test "article metadata formats its publication date" do
    layout = article_layout
    layout.page_kind(:article)
    layout.page_title("Dated")
    layout.page_metadata(publication_date: Date.new(2025, 10, 12))

    document = Nokogiri::HTML5.parse(layout.call)

    assert_equal "12 October 2025", document.at_css(".article-meta").text
    assert_equal "12 October 2025", document.at_css(".article-facts dd").text
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
