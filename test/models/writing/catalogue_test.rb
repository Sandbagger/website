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
