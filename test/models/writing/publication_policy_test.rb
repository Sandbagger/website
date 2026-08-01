# frozen_string_literal: true

require "test_helper"

class Writing::PublicationPolicyTest < ActiveSupport::TestCase
  FixedClock = Data.define(:date) do
    def today = date
  end

  test "production blocks a post before its publication date" do
    policy = policy(environment: "production", today: Date.new(2026, 7, 31))

    assert_not policy.accessible?(post_path("2026-08-01"))
    assert_not policy.published?(post_path("2026-08-01"))
  end

  test "production publishes a post on and after its publication date" do
    path = post_path("2026-08-01")

    assert policy(environment: "production", today: Date.new(2026, 8, 1)).accessible?(path)
    assert policy(environment: "production", today: Date.new(2026, 8, 2)).accessible?(path)
  end

  test "development and test preview future posts" do
    path = post_path("2026-08-01")

    assert policy(environment: "development", today: Date.new(2026, 7, 31)).accessible?(path)
    assert policy(environment: "test", today: Date.new(2026, 7, 31)).accessible?(path)
    assert_not policy(environment: "test", today: Date.new(2026, 7, 31)).published?(path)
  end

  test "drafts are previewable outside production but never published" do
    path = Writing::Path.new("app/content/pages/writing/drafts/example.markerb")

    assert policy(environment: "development", today: Date.new(2026, 8, 1)).accessible?(path)
    assert_not policy(environment: "production", today: Date.new(2026, 8, 1)).accessible?(path)
    assert_not policy(environment: "development", today: Date.new(2026, 8, 1)).published?(path)
  end

  private

  def policy(environment:, today:)
    Writing::PublicationPolicy.new(
      environment: environment,
      clock: FixedClock.new(today)
    )
  end

  def post_path(date)
    Writing::Path.new("app/content/pages/writing/posts/#{date}-example.markerb")
  end
end
