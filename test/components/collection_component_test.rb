# frozen_string_literal: true

require "test_helper"

class CollectionComponentTest < ActiveSupport::TestCase
  test "home renders a quiet empty state" do
    document = render_component([], context: :home)

    assert_equal "New writing will appear here.",
      document.at_css(".empty-state").text
    assert_nil document.at_css(".writing-feature")
  end

  test "home renders only the compact articles available" do
    document = render_component(
      [
        article("does-not-have-a-cover", "Feature"),
        article("another-note", "Another")
      ],
      context: :home
    )

    assert document.at_css(".writing-feature")
    assert_equal 1, document.css(".article-row").length
  end

  test "feature becomes text led when its cover is absent" do
    document = render_component(
      [article("does-not-have-a-cover", "Text only")],
      context: :home
    )

    assert document.at_css(".writing-feature--text-only")
    assert_nil document.at_css(".writing-feature img")
  end

  test "feature renders a dimensioned canonical WebP cover" do
    featured_article = article(
      "pettis-good-tariffs-vs-bad",
      "Michael Pettis",
      publication_date: Date.new(2025, 10, 12)
    )
    cover = Writing::Cover.find(featured_article)
    document = render_component([featured_article], context: :home)

    link = document.at_css(".writing-feature__cover")
    image = link.at_css("img")

    assert_equal "Read Michael Pettis", link["aria-label"]
    assert_equal "/images/posts/pettis-good-tariffs-vs-bad-1200w.webp", image["src"]
    assert_equal cover.srcset, image["srcset"]
    assert_equal "(max-width: 48rem) calc(100vw - clamp(2.2rem, 8vw, 6rem)), min(60vw, 47rem)", image["sizes"]
    assert_equal "1200", image["width"]
    assert_equal "630", image["height"]
    assert_equal "", image["alt"]
  end

  test "home with only a feature omits an empty article list" do
    document = render_component(
      [article("one-note", "One note")],
      context: :home
    )

    assert_nil document.at_css("ol.article-list")
  end

  test "rejects non-article collection members" do
    error = assert_raises(ArgumentError) do
      CollectionComponent.new([Object.new], context: :archive)
    end

    assert_equal "collection must contain Writing::Article instances", error.message
  end

  test "article topics render linked metadata before the publication date" do
    document = render_component(
      [
        article(
          "topic-array",
          "Topics",
          topics: ["Ruby", "Phlex"],
          publication_date: Date.new(2025, 10, 12)
        )
      ],
      context: :archive
    )

    metadata = document.at_css(".article-meta")

    assert_equal ["Ruby", "Phlex"], metadata.css("a").map(&:text)
    assert_equal ["/writing/topics/ruby", "/writing/topics/phlex"],
      metadata.css("a").map { |link| link["href"] }
    assert_equal "Ruby · Phlex · 12 October 2025", metadata.text
  end

  test "rows use article titles and canonical request paths" do
    document = render_component(
      [article("canonical", "Canonical title")],
      context: :archive
    )

    title_link = document.at_css(".article-row h3 a")
    read_link = document.at_css(".article-row > a")

    assert_equal "Canonical title", title_link.text
    assert_equal "/writing/canonical", title_link["href"]
    assert_equal "/writing/canonical", read_link["href"]
    assert_equal "Read Canonical title", read_link["aria-label"]
  end

  private

  def render_component(articles, context:)
    html = CollectionComponent.new(articles, context:).call
    Nokogiri::HTML5.fragment(html)
  end

  def article(slug, title, topics: ["Ruby"], publication_date: Date.new(2024, 3, 10))
    source = Sitepress::Page.new(
      path: "writing/posts/#{publication_date.iso8601}-#{slug}.markerb"
    )
    source.data = {"title" => title, "topic" => topics}
    root = Sitepress::Node.new
    node = root.child("remapped").child(slug)
    resource = node.resources.add Sitepress::Resource.new(
      source: source,
      node: node,
      format: :html
    )

    Writing::Article.from(resource)
  end
end
