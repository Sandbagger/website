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
