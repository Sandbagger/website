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

  test "entry is an immutable value object" do
    sitepress_resource = resource(
      "/writing/example",
      "writing/posts/2024-03-10-example.markerb"
    )
    path = Writing::Path.new(sitepress_resource.source.path)
    topics = [Writing::Topic.new(label: "Ruby")]

    entry = Writing::Catalogue::Entry.new(resource: sitepress_resource, path: path, topics: topics)
    equal_entry = Writing::Catalogue::Entry.new(resource: sitepress_resource, path: path, topics: topics)

    assert_same sitepress_resource, entry.resource
    assert_same path, entry.path
    assert_equal topics, entry.topics
    assert_equal entry, equal_entry
    assert entry.eql?(equal_entry)
    assert_equal entry.hash, equal_entry.hash
    assert_predicate entry, :frozen?
  end

  test "entry rejects an invalid resource" do
    path = Writing::Path.new("writing/posts/2024-03-10-example.markerb")
    topics = [Writing::Topic.new(label: "Ruby")]

    assert_raises(Literal::TypeError) do
      Writing::Catalogue::Entry.new(resource: Object.new, path: path, topics: topics)
    end
  end

  test "entry rejects an invalid path" do
    sitepress_resource = resource(
      "/writing/example",
      "writing/posts/2024-03-10-example.markerb"
    )

    assert_raises(Literal::TypeError) do
      Writing::Catalogue::Entry.new(resource: sitepress_resource, path: Object.new, topics: [])
    end
  end

  test "entry rejects invalid topics" do
    sitepress_resource = resource(
      "/writing/example",
      "writing/posts/2024-03-10-example.markerb"
    )
    path = Writing::Path.new(sitepress_resource.source.path)

    assert_raises(Literal::TypeError) do
      Writing::Catalogue::Entry.new(resource: sitepress_resource, path: path, topics: ["Ruby"])
    end
  end

  test "entry defensively freezes a copy of its topics" do
    sitepress_resource = resource(
      "/writing/example",
      "writing/posts/2024-03-10-example.markerb"
    )
    topics = [Writing::Topic.new(label: "Ruby")]
    entry = Writing::Catalogue::Entry.new(
      resource: sitepress_resource,
      path: Writing::Path.new(sitepress_resource.source.path),
      topics: topics
    )

    topics << Writing::Topic.new(label: "Phlex")

    assert_equal ["Ruby"], entry.topics.map(&:label)
    assert_predicate entry.topics, :frozen?
  end

  test "published selects due physical posts newest first" do
    published = resource(
      "/remapped-somewhere-else",
      "writing/posts/2024-03-10-published.markerb",
      "topic" => ["Ruby"], "publish_at" => Date.new(2099, 1, 1)
    )
    newest = resource(
      "/writing/newest",
      "writing/posts/2025-10-12-newest.markerb"
    )
    scheduled = resource(
      "/writing/scheduled",
      "writing/posts/2026-08-02-scheduled.markerb",
      "topic" => ["Ruby"], "publish_at" => Date.new(2020, 1, 1)
    )
    draft = resource(
      "/writing/drafts/draft",
      "writing/drafts/draft.markerb",
      "topic" => ["Ruby"], "publish_at" => Date.new(2020, 1, 1)
    )
    unrelated = resource(
      "/writing/impostor",
      "about.markerb",
      "publish_at" => Date.new(2020, 1, 1)
    )

    result = catalogue([published, scheduled, draft, unrelated, newest]).published

    assert_equal [newest, published], result
  end

  test "published optionally excludes a canonical request path" do
    current = resource(
      "/writing/current",
      "writing/posts/2025-10-12-current.markerb"
    )
    other = resource(
      "/writing/other",
      "writing/posts/2024-03-10-other.markerb"
    )

    assert_equal [other], catalogue([current, other]).published(exclude: "/writing/current")
  end

  test "published filters due posts by an exact typed topic in publication order" do
    ruby = Writing::Topic.new(label: "Ruby")
    newest_ruby = resource(
      "/writing/newest-ruby",
      "writing/posts/2025-10-12-newest-ruby.markerb",
      "topic" => ["Ruby"]
    )
    phlex = resource(
      "/writing/phlex",
      "writing/posts/2025-10-11-phlex.markerb",
      "topic" => ["Phlex"]
    )
    oldest_ruby = resource(
      "/writing/oldest-ruby",
      "writing/posts/2024-03-10-oldest-ruby.markerb",
      "topic" => ["Ruby", "Phlex"]
    )

    assert_equal [newest_ruby, oldest_ruby], catalogue([oldest_ruby, phlex, newest_ruby]).published(topic: ruby)
  end

  test "published applies publication filtering before topic filtering" do
    ruby = Writing::Topic.new(label: "Ruby")
    due = resource("/writing/due", "writing/posts/2026-07-31-due.markerb", "topic" => ["Ruby"])
    future = resource("/writing/future", "writing/posts/2026-08-02-future.markerb", "topic" => ["Ruby"])
    draft = resource("/writing/drafts/draft", "writing/drafts/draft.markerb", "topic" => ["Ruby"])

    assert_equal [due], catalogue([future, draft, due]).published(topic: ruby)
  end

  test "published composes topic and exclusion filters" do
    ruby = Writing::Topic.new(label: "Ruby")
    current = resource("/writing/current", "writing/posts/2025-10-12-current.markerb", "topic" => ["Ruby"])
    other = resource("/writing/other", "writing/posts/2024-03-10-other.markerb", "topic" => ["Ruby"])

    assert_equal [other], catalogue([current, other]).published(exclude: "/writing/current", topic: ruby)
  end

  test "published with a nil topic retains its unfiltered behavior" do
    ruby = resource("/writing/ruby", "writing/posts/2025-10-12-ruby.markerb", "topic" => ["Ruby"])
    phlex = resource("/writing/phlex", "writing/posts/2024-03-10-phlex.markerb", "topic" => ["Phlex"])

    assert_equal catalogue([ruby, phlex]).published, catalogue([ruby, phlex]).published(topic: nil)
  end

  test "published ignores generated topic pages and unrelated resources without writing metadata" do
    post = resource("/writing/post", "writing/posts/2025-10-12-post.markerb", "topic" => ["Ruby"])
    topic_page = topic_page_resource("/writing/topics/ruby")
    unrelated = resource("/about", "about.markerb", {})

    assert_equal [post], catalogue([topic_page, unrelated, post]).published
  end

  test "generated topic source paths are rejected before topic metadata is parsed" do
    topic_page = topic_page_resource("/writing/topics/ruby")

    assert_empty catalogue([topic_page]).published
  end

  test "published uses one date snapshot for the whole catalogue result" do
    due = resource(
      "/writing/due",
      "writing/posts/2026-07-31-due.markerb"
    )
    midnight = resource(
      "/writing/midnight",
      "writing/posts/2026-08-01-midnight.markerb"
    )
    clock = AdvancingClock.new(
      Date.new(2026, 7, 31),
      Date.new(2026, 8, 1)
    )
    policy = Writing::PublicationPolicy.new(environment: "test", clock: clock)

    result = Writing::Catalogue.new(resources: [due, midnight], policy: policy).published

    assert_equal [due], result
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

  def resource(request_path, source_path, data = {"topic" => ["Ruby"]})
    root = Sitepress::Node.new
    path = Sitepress::Path.new(request_path)
    node = path.node_names.reduce(root) { |parent, name| parent.child(name) }
    source = Sitepress::Page.new(path: source_path)
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
