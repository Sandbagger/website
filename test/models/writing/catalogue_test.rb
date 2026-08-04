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
    path = Writing::Path.new(sitepress_resource.asset.path)

    entry = Writing::Catalogue::Entry.new(resource: sitepress_resource, path: path)
    equal_entry = Writing::Catalogue::Entry.new(resource: sitepress_resource, path: path)

    assert_same sitepress_resource, entry.resource
    assert_same path, entry.path
    assert_equal entry, equal_entry
    assert entry.eql?(equal_entry)
    assert_equal entry.hash, equal_entry.hash
    assert_predicate entry, :frozen?
  end

  test "entry rejects an invalid resource" do
    path = Writing::Path.new("writing/posts/2024-03-10-example.markerb")

    assert_raises(Literal::TypeError) do
      Writing::Catalogue::Entry.new(resource: Object.new, path: path)
    end
  end

  test "entry rejects an invalid path" do
    sitepress_resource = resource(
      "/writing/example",
      "writing/posts/2024-03-10-example.markerb"
    )

    assert_raises(Literal::TypeError) do
      Writing::Catalogue::Entry.new(resource: sitepress_resource, path: Object.new)
    end
  end

  test "published selects due physical posts newest first" do
    published = resource(
      "/remapped-somewhere-else",
      "writing/posts/2024-03-10-published.markerb",
      "publish_at" => Date.new(2099, 1, 1)
    )
    newest = resource(
      "/writing/newest",
      "writing/posts/2025-10-12-newest.markerb"
    )
    scheduled = resource(
      "/writing/scheduled",
      "writing/posts/2026-08-02-scheduled.markerb",
      "publish_at" => Date.new(2020, 1, 1)
    )
    draft = resource(
      "/writing/drafts/draft",
      "writing/drafts/draft.markerb",
      "publish_at" => Date.new(2020, 1, 1)
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

  def resource(request_path, source_path, data = {})
    root = Sitepress::Node.new
    path = Sitepress::Path.new(request_path)
    node = path.node_names.reduce(root) { |parent, name| parent.child(name) }
    asset = Sitepress::Asset.new(path: source_path)
    asset.data = data

    node.resources.add_asset(asset, format: path.format)
  end
end
