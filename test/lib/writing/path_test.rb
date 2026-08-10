# frozen_string_literal: true

require "test_helper"

class Writing::PathTest < ActiveSupport::TestCase
  test "dated markerb post exposes its source, publication state, and canonical path" do
    source_path = "app/content/pages/writing/posts/2024-03-10-example.markerb"

    path = Writing::Path.new(source_path)

    assert_equal source_path, path.source_path
    assert_equal "example", path.slug
    assert_equal Date.new(2024, 3, 10), path.publication_date
    assert_equal "/writing/example", path.request_path
    assert_nil path.preview_path
    assert_predicate path, :post?
    assert_not_predicate path, :draft?
  end

  test "dated html markerb post retains dots in its slug" do
    path = Writing::Path.new(
      "app/content/pages/writing/posts/2024-03-10-an.example.html.markerb"
    )

    assert_equal "an.example", path.slug
    assert_equal Date.new(2024, 3, 10), path.publication_date
    assert_equal "/writing/an.example", path.request_path
  end

  test "dated markdown post exposes its canonical path" do
    path = Writing::Path.new(
      "app/content/pages/writing/posts/2024-03-10-example.md"
    )

    assert_equal "example", path.slug
    assert_equal Date.new(2024, 3, 10), path.publication_date
    assert_equal "/writing/example", path.request_path
  end

  test "dated markdown post preserves html in its slug" do
    path = Writing::Path.new(
      "app/content/pages/writing/posts/2024-03-10-an.example.html.md"
    )

    assert_equal "an.example.html", path.slug
  end

  test "draft exposes its source, draft state, and preview path" do
    source_path = "app/content/pages/writing/drafts/an.example.markerb"

    path = Writing::Path.new(source_path)

    assert_equal source_path, path.source_path
    assert_equal "an.example", path.slug
    assert_nil path.publication_date
    assert_equal "/writing/drafts/an.example", path.request_path
    assert_equal "/writing/drafts/an.example", path.preview_path
    assert_predicate path, :draft?
    assert_not_predicate path, :post?
  end

  test "owns and freezes parsed post values without freezing the caller" do
    source_path = +"app/content/pages/writing/posts/2024-03-10-example.markerb"

    path = Writing::Path.new(source_path)
    source_path.replace("app/content/pages/writing/drafts/changed.markerb")

    assert_equal "app/content/pages/writing/posts/2024-03-10-example.markerb", path.source_path
    assert_equal "example", path.slug
    assert_equal Date.new(2024, 3, 10), path.publication_date
    assert_equal "/writing/example", path.request_path
    assert_predicate path, :post?
    assert_not_predicate path, :draft?
    refute_same source_path, path.source_path
    assert_predicate path.source_path, :frozen?
    assert_predicate path.slug, :frozen?
    assert_predicate path, :frozen?
    refute_predicate source_path, :frozen?
  end

  test "owns and freezes parsed draft values without freezing the caller" do
    source_path = +"app/content/pages/writing/drafts/example.markerb"

    path = Writing::Path.new(source_path)
    source_path.replace("app/content/pages/writing/posts/2024-04-20-changed.markerb")

    assert_equal "app/content/pages/writing/drafts/example.markerb", path.source_path
    assert_equal "example", path.slug
    assert_nil path.publication_date
    assert_equal "/writing/drafts/example", path.request_path
    assert_predicate path, :draft?
    assert_not_predicate path, :post?
    refute_same source_path, path.source_path
    assert_predicate path.source_path, :frozen?
    assert_predicate path.slug, :frozen?
    assert_predicate path, :frozen?
    refute_predicate source_path, :frozen?
  end

  test "does not freeze or mutate an invalid caller source" do
    source_path = +"app/content/pages/writing/posts/example.markerb"

    assert_raises(Writing::Path::Invalid) { Writing::Path.new(source_path) }

    assert_equal "app/content/pages/writing/posts/example.markerb", source_path
    refute_predicate source_path, :frozen?
  end

  test "extensionless draft preserves its slug" do
    path = Writing::Path.new(
      "app/content/pages/writing/drafts/tailwind-vs-semantic-css"
    )

    assert_equal "tailwind-vs-semantic-css", path.slug
    assert_equal "/writing/drafts/tailwind-vs-semantic-css", path.preview_path
    assert_predicate path, :draft?
  end

  test "rejects a post without a date" do
    source_path = "app/content/pages/writing/posts/example.markerb"

    error = assert_raises(Writing::Path::Invalid) { Writing::Path.new(source_path) }

    assert_includes error.message, source_path
    assert_includes error.message, "date"
  end

  test "rejects a post with an impossible date" do
    source_path = "app/content/pages/writing/posts/2024-02-30-example.markerb"

    error = assert_raises(Writing::Path::Invalid) { Writing::Path.new(source_path) }

    assert_includes error.message, source_path
    assert_includes error.message, "date"
  end

  test "rejects a post without a slug" do
    source_path = "app/content/pages/writing/posts/2024-03-10-.markerb"

    error = assert_raises(Writing::Path::Invalid) { Writing::Path.new(source_path) }

    assert_includes error.message, source_path
    assert_includes error.message, "slug"
  end

  test "rejects a draft without a slug" do
    source_path = "app/content/pages/writing/drafts/.markerb"

    error = assert_raises(Writing::Path::Invalid) { Writing::Path.new(source_path) }

    assert_includes error.message, source_path
    assert_includes error.message, "slug"
  end

  test "rejects paths outside direct post and draft directories" do
    source_path = "app/content/pages/writing/posts/nested/2024-03-10-example.markerb"

    error = assert_raises(Writing::Path::Invalid) { Writing::Path.new(source_path) }

    assert_includes error.message, source_path
  end
end
