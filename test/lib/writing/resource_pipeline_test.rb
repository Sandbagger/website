# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/writing/topic")

class Writing::ResourcePipelineTest < ActiveSupport::TestCase
  test "entry is an immutable typed value object" do
    root = Sitepress::Node.new
    source_path = "app/content/pages/writing/posts/2024-03-10-example.markerb"
    resource = add_resource(root, source_path)
    path = Writing::Path.new(source_path)
    target = Writing::ResourcePipeline::Target.new(
      node_names: ["writing", "example"],
      format: :html
    )
    entry = Writing::ResourcePipeline::Entry.new(
      resource: resource,
      path: path,
      target: target,
      topics: topics_for(resource)
    )
    equal_entry = Writing::ResourcePipeline::Entry.new(
      resource: resource,
      path: path,
      target: Writing::ResourcePipeline::Target.new(
        node_names: ["writing", "example"],
        format: :html
      ),
      topics: topics_for(resource)
    )

    assert_same resource, entry.resource
    assert_equal path, entry.path
    assert_equal target, entry.target
    assert_equal ["Ruby"], entry.topics.map(&:label)
    assert_equal entry, equal_entry
    assert entry.eql?(equal_entry)
    assert_equal entry.hash, equal_entry.hash
    assert_predicate entry, :frozen?
  end

  test "entry accepts an explicit nil target but requires the keyword" do
    root = Sitepress::Node.new
    source_path = "app/content/pages/writing/drafts/example.markerb"
    resource = add_resource(root, source_path)
    path = Writing::Path.new(source_path)

    entry = Writing::ResourcePipeline::Entry.new(
      resource: resource,
      path: path,
      target: nil,
      topics: topics_for(resource)
    )

    assert_nil entry.target
    assert_raises(ArgumentError) do
      Writing::ResourcePipeline::Entry.new(resource: resource, path: path, topics: topics_for(resource))
    end
  end

  test "entry defensively freezes a copy of its topics" do
    root = Sitepress::Node.new
    source_path = "app/content/pages/writing/posts/2024-03-10-example.markerb"
    resource = add_resource(root, source_path)
    topics = [Writing::Topic.new(label: "Ruby")]
    entry = Writing::ResourcePipeline::Entry.new(
      resource: resource,
      path: Writing::Path.new(source_path),
      target: nil,
      topics: topics
    )

    topics << Writing::Topic.new(label: "Phlex")

    assert_equal ["Ruby"], entry.topics.map(&:label)
    assert_predicate entry.topics, :frozen?
  end

  test "from_props applies the immutable topics seal" do
    root = Sitepress::Node.new
    source_path = "app/content/pages/writing/posts/2024-03-10-example.markerb"
    resource = add_resource(root, source_path)
    topics = [Writing::Topic.new(label: "Ruby")]
    entry = Writing::ResourcePipeline::Entry.from_props(
      resource: resource,
      path: Writing::Path.new(source_path),
      target: nil,
      topics: topics
    )

    topics << Writing::Topic.new(label: "Phlex")

    assert_equal ["Ruby"], entry.topics.map(&:label)
    assert_predicate entry.topics, :frozen?
    refute_same topics, entry.topics
  end

  test "entry rejects invalid members" do
    root = Sitepress::Node.new
    source_path = "app/content/pages/writing/posts/2024-03-10-example.markerb"
    resource = add_resource(root, source_path)
    path = Writing::Path.new(source_path)
    target = Writing::ResourcePipeline::Target.new(
      node_names: ["writing", "example"],
      format: :html
    )

    assert_raises(Literal::TypeError) do
      Writing::ResourcePipeline::Entry.new(
        resource: Object.new, path: path, target: target, topics: topics_for(resource)
      )
    end
    assert_raises(Literal::TypeError) do
      Writing::ResourcePipeline::Entry.new(
        resource: resource, path: Object.new, target: target, topics: topics_for(resource)
      )
    end
    assert_raises(Literal::TypeError) do
      Writing::ResourcePipeline::Entry.new(
        resource: resource, path: path, target: Object.new, topics: topics_for(resource)
      )
    end
    assert_raises(Literal::TypeError) do
      Writing::ResourcePipeline::Entry.new(resource: resource, path: path, target: target, topics: ["Ruby"])
    end
  end

  test "target is an immutable value object" do
    target = Writing::ResourcePipeline::Target.new(
      node_names: ["writing", "example"],
      format: :html
    )
    equal_target = Writing::ResourcePipeline::Target.new(
      node_names: ["writing", "example"],
      format: :html
    )

    assert_equal ["writing", "example"], target.node_names
    assert_equal :html, target.format
    assert_equal target, equal_target
    assert target.eql?(equal_target)
    assert_equal target.hash, equal_target.hash
    assert_predicate target, :frozen?
  end

  test "target rejects invalid node names" do
    assert_raises(Literal::TypeError) do
      Writing::ResourcePipeline::Target.new(node_names: [1], format: :html)
    end
  end

  test "target rejects an invalid format" do
    assert_raises(Literal::TypeError) do
      Writing::ResourcePipeline::Target.new(node_names: ["writing", "example"], format: "html")
    end
  end

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

  test "generates one native HTML topic resource for a canonical writing topic" do
    root = Sitepress::Node.new
    add_resource(root, "app/content/pages/writing/posts/2024-03-10-example.markerb")

    Writing::ResourcePipeline.new(
      environment: "test",
      pages_path: "app/content/pages",
      topic_template_path: topic_template_path
    ).process(root)

    resource = root.get("/writing/topics/ruby")
    assert_instance_of Sitepress::Resource, resource
    assert_instance_of Writing::TopicPage, resource.source
    assert_equal "/writing/topics/ruby", resource.request_path
    assert_equal :html, resource.format
    assert_equal :markerb, resource.handler
    assert_equal "text/html", resource.mime_type.to_s
    assert_predicate resource, :renderable?
  end

  test "deduplicates repeated canonical topic slugs" do
    root = Sitepress::Node.new
    add_resource(root, "app/content/pages/writing/posts/2024-03-10-first.markerb", "topic" => ["Ruby"])
    add_resource(root, "app/content/pages/writing/posts/2024-03-11-second.markerb", "topic" => ["Ruby"])

    process(root)

    assert_equal 1, root.dig("writing", "topics", "ruby").resources.size
  end

  test "rejects a non-generated topic collision before mutating posts or drafts" do
    root = Sitepress::Node.new
    existing_path = "app/content/pages/legacy/ruby.markerb"
    post_path = "app/content/pages/writing/posts/2024-03-10-example.markerb"
    draft_path = "app/content/pages/writing/drafts/draft-example.markerb"
    existing = add_resource_at(root, existing_path, "/writing/topics/ruby")
    post = add_resource(root, post_path)
    draft = add_resource(root, draft_path)
    tree_before = tree_snapshot(root)

    error = assert_raises(Writing::ResourcePipeline::Invalid) { process(root) }

    assert_includes error.message, "/writing/topics/ruby"
    assert_includes error.message, '"ruby"'
    assert_includes error.message, existing_path
    assert_includes error.message, post_path
    assert_nil post.data["publish_at"]
    assert_same draft, root.get("/writing/drafts/draft-example")
    assert_equal tree_before, tree_snapshot(root)
    assert_same existing, root.get("/writing/topics/ruby")
  end

  test "production omits topics found only in drafts but includes scheduled posts" do
    root = Sitepress::Node.new
    add_resource(root, "app/content/pages/writing/drafts/draft.markerb", "topic" => ["Draft only"])
    add_resource(
      root,
      "app/content/pages/writing/posts/2099-03-10-scheduled.markerb",
      "topic" => ["Scheduled"]
    )

    process(root, environment: "production")

    assert_nil root.get("/writing/topics/draft-only")
    assert_instance_of Writing::TopicPage, root.get("/writing/topics/scheduled").source
  end

  test "production validates draft-only topic collisions before removing drafts" do
    root = Sitepress::Node.new
    draft_path = "app/content/pages/writing/drafts/draft.markerb"
    existing_path = "app/content/pages/legacy/draft-only.markerb"
    draft = add_resource(root, draft_path, "topic" => ["Draft only"])
    existing = add_resource_at(root, existing_path, "/writing/topics/draft-only")
    tree_before = tree_snapshot(root)

    error = assert_raises(Writing::ResourcePipeline::Invalid) do
      process(root, environment: "production")
    end

    assert_includes error.message, '"draft-only"'
    assert_includes error.message, draft_path
    assert_includes error.message, existing_path
    assert_same draft, root.get("/writing/drafts/draft")
    assert_same existing, root.get("/writing/topics/draft-only")
    assert_equal tree_before, tree_snapshot(root)
  end

  test "non-production generates topics found in drafts" do
    root = Sitepress::Node.new
    add_resource(root, "app/content/pages/writing/drafts/draft.markerb", "topic" => ["Draft only"])

    process(root, environment: "development")

    assert_instance_of Writing::TopicPage, root.get("/writing/topics/draft-only").source
  end

  test "rejects a missing topic template before mutating the tree" do
    root = Sitepress::Node.new
    post = add_resource(root, "app/content/pages/writing/posts/2024-03-10-example.markerb")
    tree_before = tree_snapshot(root)
    missing_template = Rails.root.join("tmp/missing-topic.markerb")

    error = assert_raises(Writing::ResourcePipeline::Invalid) do
      process(root, topic_template_path: missing_template)
    end

    assert_includes error.message, missing_template.to_s
    assert_nil post.data["publish_at"]
    assert_equal tree_before, tree_snapshot(root)
  end

  test "rejects a non-file topic template before mutating the tree" do
    root = Sitepress::Node.new
    post = add_resource(root, "app/content/pages/writing/posts/2024-03-10-example.markerb")
    tree_before = tree_snapshot(root)
    template_directory = Rails.root.join("app/content/templates")

    error = assert_raises(Writing::ResourcePipeline::Invalid) do
      process(root, topic_template_path: template_directory)
    end

    assert_includes error.message, template_directory.to_s
    assert_nil post.data["publish_at"]
    assert_equal tree_before, tree_snapshot(root)
  end

  test "validates every generated topic target before mutating the tree" do
    root = Sitepress::Node.new
    post = add_resource(
      root,
      "app/content/pages/writing/posts/2024-03-10-example.markerb",
      "topic" => ["Ruby", "Phlex"]
    )
    existing_path = "app/content/pages/legacy/phlex.markerb"
    add_resource_at(root, existing_path, "/writing/topics/phlex")
    tree_before = tree_snapshot(root)

    error = assert_raises(Writing::ResourcePipeline::Invalid) { process(root) }

    assert_includes error.message, "/writing/topics/phlex"
    assert_includes error.message, existing_path
    assert_includes error.message, post.source.path.to_s
    assert_nil post.data["publish_at"]
    assert_nil root.get("/writing/topics/ruby")
    assert_equal tree_before, tree_snapshot(root)
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

  test "makes an extensionless draft render as HTML through Markerb" do
    root = Sitepress::Node.new
    source = add_resource(
      root,
      "app/content/pages/writing/drafts/extensionless"
    )

    process(root, environment: "development")

    resource = root.get("/writing/drafts/extensionless")
    assert_equal Sitepress::Resource, resource.class
    assert_same source.source, resource.source
    assert_equal :html, resource.format
    assert_equal :markerb, resource.handler
    assert_equal "text/html", resource.mime_type.to_s
    assert_predicate resource, :renderable?
  end

  test "rejects a writing resource with a non-page source before mutating the tree" do
    root = Sitepress::Node.new
    source_path = "app/content/pages/writing/posts/2024-03-10-static.markerb"
    resource = add_static_resource(root, source_path)
    tree_before = tree_snapshot(root)

    error = assert_raises(Writing::ResourcePipeline::Invalid) { process(root) }

    assert_includes error.message, source_path
    assert_includes error.message, "Sitepress::Static"
    assert_same resource, root.get("/writing/posts/2024-03-10-static")
    assert_equal tree_before, tree_snapshot(root)
  end

  test "removes extensionless drafts in production" do
    root = Sitepress::Node.new
    add_resource(root, "app/content/pages/writing/drafts/extensionless")

    process(root, environment: "production")

    assert_nil root.get("/writing/drafts/extensionless")
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

  test "rejects flat writing resources before mutating the tree in every environment" do
    source_path = "app/content/pages/writing/misplaced.markerb"

    %w[development test production].each do |environment|
      root = Sitepress::Node.new
      resource = add_resource_at(root, source_path, "/writing/misplaced")
      tree_before = tree_snapshot(root)

      error = assert_raises(Writing::Path::Invalid) do
        process(root, environment: environment)
      end

      assert_includes error.message, source_path
      assert_same resource, root.get("/writing/misplaced")
      assert_equal tree_before, tree_snapshot(root)
    end
  end

  test "rejects nested misplaced writing resources before mutating the tree in every environment" do
    source_path = "app/content/pages/writing/notes/misplaced.markerb"

    %w[development test production].each do |environment|
      root = Sitepress::Node.new
      resource = add_resource_at(root, source_path, "/writing/notes/misplaced")
      tree_before = tree_snapshot(root)

      error = assert_raises(Writing::Path::Invalid) do
        process(root, environment: environment)
      end

      assert_includes error.message, source_path
      assert_same resource, root.get("/writing/notes/misplaced")
      assert_equal tree_before, tree_snapshot(root)
    end
  end

  test "does not classify the writing archive as a writing entry" do
    root = Sitepress::Node.new
    archive = add_resource_at(
      root,
      "app/content/pages/writing.html.markerb",
      "/writing"
    )
    tree_before = tree_snapshot(root)

    process(root, environment: "production")

    assert_same archive, root.get("/writing")
    assert_equal tree_before, tree_snapshot(root)
  end

  test "does not classify a writing directory nested below another page" do
    root = Sitepress::Node.new
    source_path = "app/content/pages/projects/writing/posts/2024-03-10-example.markerb"
    request_path = "/projects/writing/posts/2024-03-10-example"
    unrelated = add_resource_at(root, source_path, request_path)
    tree_before = tree_snapshot(root)

    process(root, environment: "production")

    assert_same unrelated, root.get(request_path)
    assert_nil root.get("/writing/example")
    assert_equal tree_before, tree_snapshot(root)
  end

  test "does not classify writing nested below another pages directory" do
    root = Sitepress::Node.new
    source_path = "app/content/pages/projects/pages/writing/posts/2024-03-10-example.markerb"
    request_path = "/projects/pages/writing/posts/2024-03-10-example"
    unrelated = add_resource_at(root, source_path, request_path)
    tree_before = tree_snapshot(root)

    process(root, environment: "production")

    assert_same unrelated, root.get(request_path)
    assert_nil root.get("/writing/example")
    assert_equal tree_before, tree_snapshot(root)
  end

  test "uses the configured pages root when its parents contain pages and writing" do
    pages_path = "/tmp/pages/writing/site/pages"
    root = Sitepress::Node.new
    post = add_resource(
      root,
      "#{pages_path}/writing/posts/2024-03-10-example.markerb"
    )

    process(root, pages_path: pages_path)

    assert_same post, root.get("/writing/example")
  end

  test "rejects misplaced writing relative to a pages root with misleading parents" do
    pages_path = "/tmp/pages/writing/site/pages"
    source_path = "#{pages_path}/writing/misplaced.markerb"
    root = Sitepress::Node.new
    resource = add_resource_at(root, source_path, "/writing/misplaced")
    tree_before = tree_snapshot(root)

    error = assert_raises(Writing::Path::Invalid) do
      process(root, pages_path: pages_path)
    end

    assert_includes error.message, source_path
    assert_same resource, root.get("/writing/misplaced")
    assert_equal tree_before, tree_snapshot(root)
  end

  test "rejects duplicate canonical slugs before mutating the tree" do
    root = Sitepress::Node.new
    first_path = "app/content/pages/writing/posts/2024-03-10-example.markerb"
    second_path = "app/content/pages/writing/posts/2025-04-11-example.html.markerb"
    add_resource(root, first_path)
    add_resource(root, second_path)

    error = assert_raises(Writing::ResourcePipeline::Invalid) { process(root) }

    assert_includes error.message, 'Duplicate writing slug "example"'
    assert_includes error.message, first_path
    assert_includes error.message, second_path
    assert root.get("/writing/posts/2024-03-10-example")
    assert root.get("/writing/posts/2025-04-11-example")
    assert_nil root.get("/writing/example")
  end

  test "rejects a slug shared by two drafts before production mutation" do
    root = Sitepress::Node.new
    first_path = "app/content/pages/writing/drafts/example.markerb"
    second_path = "app/content/pages/writing/drafts/example.html.markerb"
    add_resource_at(root, first_path, "/writing/drafts/example", "topic" => ["Ruby"])
    add_resource_at(root, second_path, "/test-fixtures/duplicate-draft", "topic" => ["Ruby"])
    tree_before = tree_snapshot(root)

    error = assert_raises(Writing::ResourcePipeline::Invalid) do
      process(root, environment: "production")
    end

    assert_includes error.message, 'Duplicate writing slug "example"'
    assert_includes error.message, first_path
    assert_includes error.message, second_path
    assert_equal tree_before, tree_snapshot(root)
  end

  test "rejects a slug shared by a draft and post before production mutation" do
    root = Sitepress::Node.new
    draft_path = "app/content/pages/writing/drafts/example.markerb"
    post_path = "app/content/pages/writing/posts/2024-03-10-example.markerb"
    add_resource(root, draft_path)
    add_resource(root, post_path)
    tree_before = tree_snapshot(root)

    error = assert_raises(Writing::ResourcePipeline::Invalid) do
      process(root, environment: "production")
    end

    assert_includes error.message, 'Duplicate writing slug "example"'
    assert_includes error.message, draft_path
    assert_includes error.message, post_path
    assert_equal tree_before, tree_snapshot(root)
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
      resource = add_resource(root, source_path, "topic" => ["Ruby"], key => "legacy")

      error = assert_raises(Writing::ResourcePipeline::Invalid) { process(root) }

      assert_includes error.message, source_path
      assert_includes error.message, key
      assert_equal "legacy", resource.data[key]
      assert root.get("/writing/posts/2024-03-10-#{key}")
    end
  end

  test "rejects invalid topic metadata before mutating the tree" do
    invalid_topics = {
      "scalar" => [{"topic" => "Ruby"}, "topic must be an array"],
      "missing" => [{}, "missing topic metadata"],
      "empty" => [{"topic" => []}, "topic must not be empty"],
      "padded" => [{"topic" => [" Ruby"]}, "topic[0] must not have surrounding whitespace"],
      "non-string" => [{"topic" => [1]}, "topic[0] must be a string"],
      "duplicate" => [{"topic" => ["Ruby", "ruby"]}, "duplicate topic \"ruby\""]
    }

    invalid_topics.each do |name, (data, reason)|
      root = Sitepress::Node.new
      source_path = "app/content/pages/writing/posts/2024-03-10-#{name}.markerb"
      add_resource(root, source_path, data)
      tree_before = tree_snapshot(root)

      error = assert_raises(Writing::ResourcePipeline::Invalid) { process(root) }

      assert_equal "Invalid topic metadata in #{source_path.inspect}: #{reason}", error.message
      assert_instance_of Writing::Topic::Invalid, error.cause
      assert_equal tree_before, tree_snapshot(root)
    end
  end

  test "identifies invalid topic labels by index" do
    root = Sitepress::Node.new
    source_path = "app/content/pages/writing/posts/2024-03-10-invalid-topic.markerb"
    add_resource(root, source_path, "topic" => ["Ruby", 1])
    tree_before = tree_snapshot(root)

    error = assert_raises(Writing::ResourcePipeline::Invalid) { process(root) }

    assert_includes error.message, "Invalid topic metadata in #{source_path.inspect}: topic[1] must be a string"
    assert_equal tree_before, tree_snapshot(root)
  end

  test "rejects inconsistent topic capitalization across production drafts before mutation" do
    root = Sitepress::Node.new
    first_path = "app/content/pages/writing/drafts/ruby.markerb"
    second_path = "app/content/pages/writing/drafts/lowercase-ruby.markerb"
    add_resource(root, first_path, "topic" => ["Ruby"])
    add_resource(root, second_path, "topic" => ["ruby"])
    tree_before = tree_snapshot(root)

    error = assert_raises(Writing::ResourcePipeline::Invalid) do
      process(root, environment: "production")
    end

    assert_includes error.message, "inconsistent canonical display capitalization"
    assert_includes error.message, first_path
    assert_includes error.message, second_path
    assert_equal tree_before, tree_snapshot(root)
  end

  test "rejects topic labels with colliding slugs across production drafts before mutation" do
    root = Sitepress::Node.new
    first_path = "app/content/pages/writing/drafts/c.markerb"
    second_path = "app/content/pages/writing/drafts/c-plus-plus.markerb"
    add_resource(root, first_path, "topic" => ["C"])
    add_resource(root, second_path, "topic" => ["C++"])
    tree_before = tree_snapshot(root)

    error = assert_raises(Writing::ResourcePipeline::Invalid) do
      process(root, environment: "production")
    end

    assert_includes error.message, "slug collision"
    assert_includes error.message, '"c"'
    assert_includes error.message, first_path
    assert_includes error.message, second_path
    assert_equal tree_before, tree_snapshot(root)
  end

  private

  def process(root, environment: "test", pages_path: "app/content/pages", topic_template_path: self.topic_template_path)
    Writing::ResourcePipeline.new(
      environment: environment,
      pages_path: pages_path,
      topic_template_path: topic_template_path
    ).process(root)
  end

  def topic_template_path
    Rails.root.join("app/content/templates/topic.markerb")
  end

  def add_resource(root, source_path, data = nil)
    source = Sitepress::Page.new(path: source_path)
    source.data = data || {"topic" => ["Ruby"]}

    kind, filename = source_path.match(%r{/writing/(posts|drafts)/([^/]+)\z}).captures
    path = Sitepress::Path.new(filename)
    node = root.child("writing").child(kind).child(path.node_name)

    node.resources.add Sitepress::Resource.new(
      source: source,
      node: node,
      format: path.format || node.default_format
    )
  end

  def add_resource_at(root, source_path, request_path, data = {})
    source = Sitepress::Page.new(path: source_path)
    source.data = data
    path = Sitepress::Path.new(request_path)
    node = path.node_names.reduce(root) { |parent, name| parent.child(name) }

    node.resources.add Sitepress::Resource.new(
      source: source,
      node: node,
      format: path.format || node.default_format
    )
  end

  def add_static_resource(root, source_path)
    source = Sitepress::Static.new(path: source_path)
    path = Sitepress::Path.new(source_path.split("/").last)
    node = root.child("writing").child("posts").child(path.node_name)

    node.resources.add Sitepress::Resource.new(
      source: source,
      node: node,
      format: path.format || node.default_format
    )
  end

  def tree_snapshot(node)
    {
      resources: node.resources.map do |resource|
        [resource.object_id, resource.request_path, resource.source.path.to_s]
      end,
      children: node.children.to_h do |child|
        [child.name, tree_snapshot(child)]
      end
    }
  end

  def topics_for(resource)
    Writing::Topic.from(resource.data, source_path: resource.source.path.to_s)
  end
end
