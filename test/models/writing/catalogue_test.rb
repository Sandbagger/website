# frozen_string_literal: true

require "test_helper"

class Writing::CatalogueTest < ActiveSupport::TestCase
  FixedClock = Data.define(:date) do
    def today = date
  end

  class AdvancingClock
    attr_reader :calls

    def initialize(*dates)
      @dates = dates
      @calls = 0
    end

    def today
      @dates.fetch(@calls, @dates.last).tap { @calls += 1 }
    end
  end

  test "published returns due articles newest first from physical paths" do
    published = resource(
      "/remapped-somewhere-else",
      "writing/posts/2024-03-10-published.markerb",
      title: "Published"
    )
    newest = resource(
      "/also-remapped",
      "writing/posts/2025-10-12-newest.markerb",
      title: "Newest"
    )
    scheduled = resource(
      "/writing/scheduled",
      "writing/posts/2026-08-02-scheduled.markerb",
      title: "Scheduled"
    )
    draft = resource(
      "/writing/drafts/draft",
      "writing/drafts/draft.markerb",
      title: "Draft"
    )
    unrelated = resource(
      "/about",
      "about.markerb",
      title: "About"
    )

    result = catalogue([published, scheduled, draft, unrelated, newest]).published

    assert result.all? { |article| article.is_a?(Writing::Article) }
    assert_equal ["Newest", "Published"], result.map(&:title)
    assert_equal ["/writing/newest", "/writing/published"], result.map(&:request_path)
    assert_equal [Date.new(2025, 10, 12), Date.new(2024, 3, 10)], result.map(&:publication_date)
  end

  test "published excludes a canonical article request path after resource remapping" do
    current = resource(
      "/remapped-current",
      "writing/posts/2025-10-12-current.markerb",
      title: "Current"
    )
    other = resource(
      "/remapped-other",
      "writing/posts/2024-03-10-other.markerb",
      title: "Other"
    )

    result = catalogue([current, other]).published(exclude: "/writing/current")

    assert_equal ["/writing/other"], result.map(&:request_path)
  end

  test "published filters by an exact typed topic in publication order" do
    ruby = Writing::Topic.new(label: "Ruby")
    newest_ruby = resource(
      "/writing/newest-ruby",
      "writing/posts/2025-10-12-newest-ruby.markerb",
      title: "Newest Ruby",
      topics: ["Ruby"]
    )
    phlex = resource(
      "/writing/phlex",
      "writing/posts/2025-10-11-phlex.markerb",
      title: "Phlex",
      topics: ["Phlex"]
    )
    oldest_ruby = resource(
      "/writing/oldest-ruby",
      "writing/posts/2024-03-10-oldest-ruby.markerb",
      title: "Oldest Ruby",
      topics: ["Ruby", "Phlex"]
    )

    result = catalogue([oldest_ruby, phlex, newest_ruby]).published(topic: ruby)

    assert_equal ["Newest Ruby", "Oldest Ruby"], result.map(&:title)
    assert_equal [["Ruby"], ["Ruby", "Phlex"]],
      result.map { |article| article.topics.map(&:label) }
  end

  test "published composes due topic and exclusion filters" do
    ruby = Writing::Topic.new(label: "Ruby")
    current = resource(
      "/remapped-current",
      "writing/posts/2025-10-12-current.markerb",
      title: "Current",
      topics: ["Ruby"]
    )
    other = resource(
      "/remapped-other",
      "writing/posts/2024-03-10-other.markerb",
      title: "Other",
      topics: ["Ruby"]
    )
    phlex = resource(
      "/writing/phlex",
      "writing/posts/2024-03-09-phlex.markerb",
      title: "Phlex",
      topics: ["Phlex"]
    )
    future = resource(
      "/writing/future",
      "writing/posts/2026-08-02-future.markerb",
      title: "Future",
      topics: ["Ruby"]
    )
    draft = resource(
      "/writing/drafts/draft",
      "writing/drafts/draft.markerb",
      title: "Draft",
      topics: ["Ruby"]
    )

    result = catalogue([future, draft, current, phlex, other]).published(
      exclude: "/writing/current",
      topic: ruby
    )

    assert_equal ["Other"], result.map(&:title)
  end

  test "published with nil topic retains its unfiltered behavior" do
    ruby = resource(
      "/writing/ruby",
      "writing/posts/2025-10-12-ruby.markerb",
      title: "Ruby",
      topics: ["Ruby"]
    )
    phlex = resource(
      "/writing/phlex",
      "writing/posts/2024-03-10-phlex.markerb",
      title: "Phlex",
      topics: ["Phlex"]
    )

    without_topic = catalogue([ruby, phlex]).published
    with_nil_topic = catalogue([ruby, phlex]).published(topic: nil)

    assert_equal without_topic.map(&:request_path), with_nil_topic.map(&:request_path)
  end

  test "published rejects false as a topic instead of broadening results" do
    ruby = resource(
      "/writing/ruby",
      "writing/posts/2025-10-12-ruby.markerb",
      title: "Ruby"
    )

    assert_raises(ArgumentError) { catalogue([ruby]).published(topic: false) }
  end

  test "published rejects non-topic values instead of broadening results" do
    ruby = resource(
      "/writing/ruby",
      "writing/posts/2025-10-12-ruby.markerb",
      title: "Ruby"
    )

    assert_raises(ArgumentError) { catalogue([ruby]).published(topic: "Ruby") }
  end

  test "published does not match a differently capitalized typed topic" do
    ruby = resource(
      "/writing/ruby",
      "writing/posts/2025-10-12-ruby.markerb",
      title: "Ruby",
      topics: ["Ruby"]
    )

    assert_empty catalogue([ruby]).published(topic: Writing::Topic.new(label: "ruby"))
  end

  test "published ignores generated topic pages and unrelated resources" do
    post = resource(
      "/writing/post",
      "writing/posts/2025-10-12-post.markerb",
      title: "Post"
    )
    topic_page = topic_page_resource("/writing/topics/ruby")
    unrelated = resource("/about", "about.markerb", title: "About")

    result = catalogue([topic_page, unrelated, post]).published

    assert_equal ["Post"], result.map(&:title)
  end

  test "generated topic source paths are rejected before metadata is parsed" do
    topic_page = topic_page_resource("/writing/topics/ruby")
    topic_page.define_singleton_method(:data) { fail "metadata was parsed" }

    assert_empty catalogue([topic_page]).published
  end

  test "recognized writing paths keep invalid frontmatter fatal" do
    invalid = resource(
      "/writing/invalid",
      "writing/posts/2025-10-12-invalid.markerb",
      title: nil
    )

    error = assert_raises(Writing::Frontmatter::Invalid) do
      catalogue([invalid]).published
    end

    assert_includes error.message, "missing title metadata"
  end

  test "published uses one date snapshot for the whole catalogue result" do
    due = resource(
      "/writing/due",
      "writing/posts/2026-07-31-due.markerb",
      title: "Due"
    )
    midnight = resource(
      "/writing/midnight",
      "writing/posts/2026-08-01-midnight.markerb",
      title: "Midnight"
    )
    clock = AdvancingClock.new(
      Date.new(2026, 7, 31),
      Date.new(2026, 8, 1)
    )
    policy = Writing::PublicationPolicy.new(environment: "test", clock: clock)

    result = Writing::Catalogue.new(resources: [due, midnight], policy: policy).published

    assert_equal ["Due"], result.map(&:title)
    assert_equal 1, clock.calls
  end

  private

  def catalogue(resources)
    policy = Writing::PublicationPolicy.new(
      environment: "test",
      clock: FixedClock.new(Date.new(2026, 8, 1))
    )

    Writing::Catalogue.new(resources: resources, policy: policy)
  end

  def resource(request_path, source_path, title:, topics: ["Ruby"])
    root = Sitepress::Node.new
    path = Sitepress::Path.new(request_path)
    node = path.node_names.reduce(root) { |parent, name| parent.child(name) }
    source = Sitepress::Page.new(path: source_path)
    data = {"topic" => topics}
    data["title"] = title if title
    source.data = data

    node.resources.add Sitepress::Resource.new(
      source: source,
      node: node,
      format: path.format || node.default_format
    )
  end

  def topic_page_resource(request_path)
    root = Sitepress::Node.new
    path = Sitepress::Path.new(request_path)
    node = path.node_names.reduce(root) { |parent, name| parent.child(name) }
    source = Writing::TopicPage.new(
      path: Rails.root.join("app/content/templates/topic.markerb"),
      topic: Writing::Topic.new(label: "Ruby")
    )

    node.resources.add Sitepress::Resource.new(
      source: source,
      node: node,
      format: path.format || node.default_format
    )
  end
end
