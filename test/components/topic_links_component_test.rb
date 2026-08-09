require "test_helper"

class TopicLinksComponentTest < ActiveSupport::TestCase
  test "renders topics in authored order as links separated by dots" do
    document = render_component("Tariffs", "Macroeconomics")

    assert_equal ["Tariffs", "Macroeconomics"], document.css("a").map(&:text)
    assert_equal ["/writing/topics/tariffs", "/writing/topics/macroeconomics"],
      document.css("a").map { |link| link["href"] }
    assert_equal "Tariffs · Macroeconomics", document.text
  end

  test "renders nothing for an empty collection" do
    document = render_component

    assert_empty document.css("a")
    assert_equal "", document.text
  end

  private

  def render_component(*labels)
    topics = labels.map { |label| Writing::Topic.new(label:) }
    Nokogiri::HTML5.fragment(TopicLinksComponent.new(topics).call)
  end
end
