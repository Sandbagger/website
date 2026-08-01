# frozen_string_literal: true

require "test_helper"

class Writing::ResourcePipelineTest < ActiveSupport::TestCase
  test "maps a dated post to its canonical request path and derives publish_at" do
    root = Sitepress::Node.new
    resource = add_resource(
      root,
      "app/content/pages/writing/posts/2024-03-10-example.html.markerb"
    )

    process(root)

    assert_same resource, root.get("/writing/example")
    assert_equal "/writing/example", resource.request_path
    assert_equal Date.new(2024, 3, 10), resource.data["publish_at"]
    assert_nil root.get("/writing/posts/2024-03-10-example")
  end

  test "maps a markdown post to the canonical HTML request path" do
    root = Sitepress::Node.new
    resource = add_resource(
      root,
      "app/content/pages/writing/posts/2024-03-10-example.md"
    )

    process(root)

    assert_same resource, root.get("/writing/example")
    assert_equal "/writing/example", resource.request_path
    assert_nil root.get("/writing/posts/2024-03-10-example.md")
  end

  test "maps a dotted slug using Sitepress canonical path semantics" do
    root = Sitepress::Node.new
    source_path = "app/content/pages/writing/posts/2024-03-10-an.example.html.markerb"
    path = Writing::Path.new(source_path)
    resource = add_resource(root, source_path)

    process(root)

    assert_same resource, root.get(path.request_path)
    assert_equal path.request_path, resource.request_path
    assert_nil root.get("/writing/posts/2024-03-10-an.example")
  end

  test "keeps a draft at its preview path outside production" do
    root = Sitepress::Node.new
    resource = add_resource(
      root,
      "app/content/pages/writing/drafts/unfinished.markerb"
    )

    process(root, environment: "development")

    assert_same resource, root.get("/writing/drafts/unfinished")
  end

  test "removes drafts but keeps scheduled posts in production" do
    root = Sitepress::Node.new
    add_resource(root, "app/content/pages/writing/drafts/unfinished.markerb")
    scheduled = add_resource(
      root,
      "app/content/pages/writing/posts/2099-03-10-scheduled.markerb"
    )

    process(root, environment: "production")

    assert_nil root.get("/writing/drafts/unfinished")
    assert_same scheduled, root.get("/writing/scheduled")
    assert_equal Date.new(2099, 3, 10), scheduled.data["publish_at"]
  end

  test "rejects duplicate canonical slugs before mutating the tree" do
    root = Sitepress::Node.new
    first_path = "app/content/pages/writing/posts/2024-03-10-example.markerb"
    second_path = "app/content/pages/writing/posts/2025-04-11-example.html.markerb"
    add_resource(root, first_path)
    add_resource(root, second_path)

    error = assert_raises(Writing::ResourcePipeline::Invalid) { process(root) }

    assert_includes error.message, first_path
    assert_includes error.message, second_path
    assert root.get("/writing/posts/2024-03-10-example")
    assert root.get("/writing/posts/2025-04-11-example")
    assert_nil root.get("/writing/example")
  end

  test "rejects a canonical collision with a non-writing resource before mutation" do
    root = Sitepress::Node.new
    existing_path = "app/content/pages/legacy/an-example.markerb"
    post_path = "app/content/pages/writing/posts/2024-03-10-an.example.markerb"
    existing = add_resource_at(root, existing_path, "/writing/an.example")
    post = add_resource(root, post_path)
    children_before = root.dig("writing").children.map(&:name).sort

    error = assert_raises(Writing::ResourcePipeline::Invalid) { process(root) }

    assert_includes error.message, existing_path
    assert_includes error.message, post_path
    assert_nil post.data["publish_at"]
    assert_same existing, root.get("/writing/an.example")
    assert_same post, root.get("/writing/posts/2024-03-10-an.example")
    assert_equal children_before, root.dig("writing").children.map(&:name).sort
  end

  test "rejects legacy writing metadata with its source path and key" do
    %w[status published publish_at].each do |key|
      root = Sitepress::Node.new
      source_path = "app/content/pages/writing/posts/2024-03-10-#{key}.markerb"
      resource = add_resource(root, source_path, key => "legacy")

      error = assert_raises(Writing::ResourcePipeline::Invalid) { process(root) }

      assert_includes error.message, source_path
      assert_includes error.message, key
      assert_equal "legacy", resource.data[key]
      assert root.get("/writing/posts/2024-03-10-#{key}")
    end
  end

  private

  def process(root, environment: "test")
    Writing::ResourcePipeline.new(environment: environment).process(root)
  end

  def add_resource(root, source_path, data = {})
    asset = Sitepress::Asset.new(path: source_path)
    asset.data = data

    kind, filename = source_path.match(%r{/writing/(posts|drafts)/([^/]+)\z}).captures
    node_name = Sitepress::Path.new(filename).node_name
    node = root.child("writing").child(kind).child(node_name)

    node.resources.add_asset(asset, format: asset.format)
  end

  def add_resource_at(root, source_path, request_path)
    asset = Sitepress::Asset.new(path: source_path)
    asset.data = {}
    path = Sitepress::Path.new(request_path)
    node = path.node_names.reduce(root) { |parent, name| parent.child(name) }

    node.resources.add_asset(asset, format: path.format)
  end
end
