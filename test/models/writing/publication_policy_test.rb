# frozen_string_literal: true

require "test_helper"

class Writing::PublicationPolicyTest < ActiveSupport::TestCase
  FixedClock = Data.define(:date) do
    def today = date
  end

  test "production blocks a post before its publication date" do
    policy = policy(environment: "production", today: Date.new(2026, 7, 31))
    article = post_article("2026-08-01")

    assert_not policy.accessible?(article)
    assert_not policy.published?(article)
  end

  test "production publishes a post on and after its publication date" do
    article = post_article("2026-08-01")
    publication_day = policy(environment: "production", today: Date.new(2026, 8, 1))
    day_after_publication = policy(environment: "production", today: Date.new(2026, 8, 2))

    assert publication_day.accessible?(article)
    assert publication_day.published?(article)
    assert day_after_publication.accessible?(article)
    assert day_after_publication.published?(article)
  end

  test "development and test preview future posts" do
    article = post_article("2026-08-01")

    assert policy(environment: "development", today: Date.new(2026, 7, 31)).accessible?(article)
    assert policy(environment: "test", today: Date.new(2026, 7, 31)).accessible?(article)
    assert_not policy(environment: "test", today: Date.new(2026, 7, 31)).published?(article)
  end

  test "drafts are previewable outside production but never published" do
    article = build_article("app/content/pages/writing/drafts/example.markerb")

    assert policy(environment: "development", today: Date.new(2026, 8, 1)).accessible?(article)
    assert_not policy(environment: "production", today: Date.new(2026, 8, 1)).accessible?(article)
    assert_not policy(environment: "development", today: Date.new(2026, 8, 1)).published?(article)
  end

  private

  def policy(environment:, today:)
    Writing::PublicationPolicy.new(
      environment: environment,
      clock: FixedClock.new(today)
    )
  end

  def post_article(date)
    build_article("app/content/pages/writing/posts/#{date}-example.markerb")
  end

  def build_article(source_path)
    path = Writing::Path.new(source_path)
    frontmatter = Writing::Frontmatter.new(
      title: "Example",
      topics: [Writing::Topic.new(label: "Ruby")]
    )

    Writing::Article.new(path:, frontmatter:)
  end
end
