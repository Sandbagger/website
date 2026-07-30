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

  test "home with only a feature omits an empty article list" do
    document = render_component(
      [resource("/writing/one-note", "One note")],
      context: :home
    )

    assert_nil document.at_css("ol.article-list")
  end

  test "missing topic and date produce a title link without placeholders" do
    document = render_component(
      [resource("/writing/title-only", "Title only")],
      context: :archive
    )

    assert_equal "Title only", document.at_css(".article-row h3 a").text
    assert_nil document.at_css(".article-row .article-meta")
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

  test "numeric topics render as metadata" do
    document = render_component(
      [Resource.new("/writing/numeric-topic", {"title" => "Numeric", "topic" => 37})],
      context: :archive
    )

    assert_equal "37", document.at_css(".article-meta").text
  end

  private

  def render_component(resources, context:)
    html = CollectionComponent.new(resources, context:).call
    Nokogiri::HTML5.fragment(html)
  end

  def resource(path, title)
    Resource.new(path, {"title" => title})
  end
end
