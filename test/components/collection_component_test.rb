require "test_helper"

class CollectionComponentTest < ActiveSupport::TestCase
  Resource = Data.define(:request_path, :data)

  test "home renders a quiet empty state" do
    document = render_component([], context: :home)

    assert_equal "New writing will appear here.",
      document.at_css(".empty-state").text
    assert_nil document.at_css(".writing-feature")
  end

  test "home renders only the compact resources available" do
    document = render_component(
      [
        resource("/writing/does-not-have-a-cover", "Feature"),
        resource("/writing/another-note", "Another")
      ],
      context: :home
    )

    assert document.at_css(".writing-feature")
    assert_equal 1, document.css(".article-row").length
  end

  test "feature becomes text led when its cover is absent" do
    document = render_component(
      [resource("/writing/does-not-have-a-cover", "Text only")],
      context: :home
    )

    assert document.at_css(".writing-feature--text-only")
    assert_nil document.at_css(".writing-feature img")
  end

  test "feature renders a dimensioned canonical WebP cover" do
    featured_resource = resource("/writing/pettis-good-tariffs-vs-bad", "Michael Pettis")
    cover = Writing::Cover.find(featured_resource)
    document = render_component(
      [featured_resource],
      context: :home
    )

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
      [resource("/writing/one-note", "One note")],
      context: :home
    )

    assert_nil document.at_css("ol.article-list")
  end

  test "missing topic metadata raises with the resource diagnostic path" do
    error = assert_raises(Writing::Topic::Invalid) do
      render_component(
        [Resource.new("/writing/title-only", Sitepress::Data.manage("title" => "Title only"))],
        context: :archive
      )
    end

    assert_includes error.message, %("/writing/title-only")
    assert_includes error.message, "missing topic metadata"
  end

  test "blank titles fall back to request paths in titles and aria labels" do
    document = render_component(
      [
        resource("/writing/nil-title", nil),
        resource("/writing/blank-title", "   ")
      ],
      context: :archive
    )

    assert_equal ["/writing/nil-title", "/writing/blank-title"],
      document.css(".article-row h3 a").map(&:text)
    assert_equal ["Read /writing/nil-title", "Read /writing/blank-title"],
      document.css(".article-row > a").map { |link| link["aria-label"] }
  end

  test "topic arrays render linked metadata before the date" do
    document = render_component(
      [resource("/writing/topic-array", "Topics", topics: ["Ruby", "Phlex"], publish_at: Date.new(2025, 10, 12))],
      context: :archive
    )

    metadata = document.at_css(".article-meta")

    assert_equal ["Ruby", "Phlex"], metadata.css("a").map(&:text)
    assert_equal ["/writing/topics/ruby", "/writing/topics/phlex"],
      metadata.css("a").map { |link| link["href"] }
    assert_equal "Ruby · Phlex · 12 October 2025", metadata.text
  end

  private

  def render_component(resources, context:)
    html = CollectionComponent.new(resources, context:).call
    Nokogiri::HTML5.fragment(html)
  end

  def resource(path, title, topics: ["Ruby"], publish_at: nil)
    data = {"title" => title}
    data["topic"] = topics
    data["publish_at"] = publish_at if publish_at

    Resource.new(path, Sitepress::Data.manage(data))
  end
end
