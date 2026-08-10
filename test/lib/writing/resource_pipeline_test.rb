# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/writing/topic")
require Rails.root.join("lib/writing/frontmatter")
require Rails.root.join("lib/writing/article")

class Writing::ResourcePipelineTest < ActiveSupport::TestCase
  test "entry is an immutable typed value object" do
    root = Sitepress::Node.new
    source_path = "app/content/pages/writing/posts/2024-03-10-example.markerb"
    resource = add_resource(root, source_path)
    article = Writing::Article.from(resource)
    target = Writing::ResourcePipeline::Target.new(
      node_names: ["writing", "example"],
      format: :html
    )
    entry = Writing::ResourcePipeline::Entry.new(
      resource: resource,
      article: article,
      target: target
    )
    equal_entry = Writing::ResourcePipeline::Entry.new(
      resource: resource,
      article: article,
      target: Writing::ResourcePipeline::Target.new(
        node_names: ["writing", "example"],
        format: :html
      )
    )

    assert_same resource, entry.resource
    assert_same article, entry.article
    assert_equal target, entry.target
    assert_equal entry, equal_entry
    assert entry.eql?(equal_entry)
    assert_equal entry.hash, equal_entry.hash
    assert_predicate entry, :frozen?
  end

  test "entry accepts an explicit or default nil target" do
    root = Sitepress::Node.new
    source_path = "app/content/pages/writing/drafts/example.markerb"
    resource = add_resource(root, source_path)
    article = Writing::Article.from(resource)

    entry = Writing::ResourcePipeline::Entry.new(
      resource: resource,
      article: article,
      target: nil
    )
    default_target = Writing::ResourcePipeline::Entry.new(
      resource: resource,
      article: article
    )

    assert_nil entry.target
    assert_nil default_target.target
  end

  test "entry equality requires the same identity article" do
    root = Sitepress::Node.new
    source_path = "app/content/pages/writing/posts/2024-03-10-example.markerb"
    resource = add_resource(root, source_path)
    first_article = Writing::Article.from(resource)
    second_article = Writing::Article.from(resource)

    first = Writing::ResourcePipeline::Entry.new(
      resource: resource,
      article: first_article,
      target: nil
    )
    second = Writing::ResourcePipeline::Entry.new(
      resource: resource,
      article: second_article,
      target: nil
    )

    refute_equal first, second
  end

  test "entry rejects invalid members" do
    root = Sitepress::Node.new
    source_path = "app/content/pages/writing/posts/2024-03-10-example.markerb"
    resource = add_resource(root, source_path)
    article = Writing::Article.from(resource)
    target = Writing::ResourcePipeline::Target.new(
      node_names: ["writing", "example"],
      format: :html
    )

    assert_raises(Literal::TypeError) do
      Writing::ResourcePipeline::Entry.new(
        resource: Object.new, article: article, target: target
      )
    end
    assert_raises(Literal::TypeError) do
      Writing::ResourcePipeline::Entry.new(
        resource: resource, article: Object.new, target: target
      )
    end
    assert_raises(Literal::TypeError) do
      Writing::ResourcePipeline::Entry.new(
        resource: resource, article: article, target: Object.new
      )
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

  test "target deeply owns its node names" do
    node_names = [+"writing", +"example"]
    caller_name = node_names.first
    target = Writing::ResourcePipeline::Target.new(node_names: node_names, format: :html)
    equal_target = Writing::ResourcePipeline::Target.new(
      node_names: ["writing", "example"],
      format: :html
    )
    original_hash = target.hash

    caller_name << "-mutated"
    node_names << +"extra"

    assert_equal ["writing", "example"], target.node_names
    assert_equal equal_target, target
    assert_equal original_hash, target.hash
    assert_predicate target.node_names, :frozen?
    assert target.node_names.all?(&:frozen?)
    refute_same node_names, target.node_names
    refute_same caller_name, target.node_names.first
    refute_predicate node_names, :frozen?
    refute_predicate caller_name, :frozen?
  end

  test "target from_props deeply owns its node names" do
    node_names = [+"writing", +"example"]
    caller_name = node_names.first
    target = Writing::ResourcePipeline::Target.from_props(
      node_names: node_names,
      format: :html
    )
    equal_target = Writing::ResourcePipeline::Target.new(
      node_names: ["writing", "example"],
      format: :html
    )
    original_hash = target.hash

    caller_name.replace("changed")
    node_names.clear

    assert_equal ["writing", "example"], target.node_names
    assert_equal equal_target, target
    assert_equal original_hash, target.hash
    assert_predicate target.node_names, :frozen?
    assert target.node_names.all?(&:frozen?)
    refute_same node_names, target.node_names
    refute_same caller_name, target.node_names.first
    refute_predicate node_names, :frozen?
    refute_predicate caller_name, :frozen?
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
    add_resource(
      root,
      "app/content/pages/writing/posts/2024-03-10-first.markerb",
      "title" => "First",
      "topic" => ["Ruby"]
    )
    add_resource(
      root,
      "app/content/pages/writing/posts/2024-03-11-second.markerb",
      "title" => "Second",
      "topic" => ["Ruby"]
    )

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
    add_resource(
      root,
      "app/content/pages/writing/drafts/draft.markerb",
      "title" => "Draft",
      "topic" => ["Draft only"]
    )
    add_resource(
      root,
      "app/content/pages/writing/posts/2099-03-10-scheduled.markerb",
      "title" => "Scheduled",
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
    draft = add_resource(
      root,
      draft_path,
      "title" => "Draft",
      "topic" => ["Draft only"]
    )
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
    add_resource(
      root,
      "app/content/pages/writing/drafts/draft.markerb",
      "title" => "Draft",
      "topic" => ["Draft only"]
    )

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
      "title" => "Example",
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
    add_resource_at(
      root,
      first_path,
      "/writing/drafts/example",
      "title" => "First",
      "topic" => ["Ruby"]
    )
    add_resource_at(
      root,
      second_path,
      "/test-fixtures/duplicate-draft",
      "title" => "Second",
      "topic" => ["Ruby"]
    )
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

  test "preflights closed frontmatter before any mutation in every environment" do
    frontmatter_failures.each do |name, data, reason, nested_cause|
      %w[development test production].each do |environment|
        assert_frontmatter_preflight_failure(
          name:,
          data:,
          reason:,
          nested_cause:,
          environment:
        )
      end
    end
  end

  test "rejects inconsistent topic capitalization across production drafts before mutation" do
    root = Sitepress::Node.new
    first_path = "app/content/pages/writing/drafts/ruby.markerb"
    second_path = "app/content/pages/writing/drafts/lowercase-ruby.markerb"
    add_resource(root, first_path, "title" => "Ruby", "topic" => ["Ruby"])
    add_resource(root, second_path, "title" => "Lowercase Ruby", "topic" => ["ruby"])
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
    add_resource(root, first_path, "title" => "C", "topic" => ["C"])
    add_resource(root, second_path, "title" => "C++", "topic" => ["C++"])
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

  def frontmatter_failures
    valid = {"title" => "Invalid", "topic" => ["Ruby"]}

    [
      ["unknown", valid.merge("layout" => "article"), 'unknown metadata "layout"', nil],
      ["legacy-status", valid.merge("status" => "draft"), 'unknown metadata "status"', nil],
      ["legacy-published", valid.merge("published" => true), 'unknown metadata "published"', nil],
      ["legacy-publish-at", valid.merge("publish_at" => Date.new(2024, 3, 10)), 'unknown metadata "publish_at"', nil],
      ["missing-title", {"topic" => ["Ruby"]}, "missing title metadata", nil],
      ["missing-topic", {"title" => "Missing topic"}, "missing topic metadata", nil],
      ["title-type", valid.merge("title" => 1), "title must be a string", nil],
      ["title-blank", valid.merge("title" => " "), "title must not be blank", nil],
      ["title-padded", valid.merge("title" => " Invalid"), "title must not have surrounding whitespace", nil],
      ["topic-scalar", valid.merge("topic" => "Ruby"), "topic must be an array", Writing::Topic::Invalid],
      ["topic-empty", valid.merge("topic" => []), "topic must not be empty", Writing::Topic::Invalid],
      ["topic-type", valid.merge("topic" => [1]), "topic[0] must be a string", Writing::Topic::Invalid],
      ["topic-padded", valid.merge("topic" => [" Ruby"]), "topic[0] must not have surrounding whitespace", Writing::Topic::Invalid],
      ["topic-slugless", valid.merge("topic" => ["!!!"]), "topic[0] must produce a slug", Writing::Topic::Invalid],
      ["topic-duplicate", valid.merge("topic" => ["Ruby", "ruby"]), 'duplicate topic "ruby"', Writing::Topic::Invalid],
      ["emoji-type", valid.merge("emoji" => false), "emoji must be a string", nil],
      ["emoji-blank", valid.merge("emoji" => " "), "emoji must not be blank", nil],
      ["emoji-padded", valid.merge("emoji" => " 🦄"), "emoji must not have surrounding whitespace", nil],
      ["ordered-unknown", {"zeta" => true, "alpha" => true}, 'unknown metadata "alpha"', nil],
      ["ordered-missing", {}, "missing title metadata", nil],
      ["ordered-title", {"title" => " ", "topic" => "Ruby"}, "title must not be blank", nil],
      ["ordered-topic", valid.merge("topic" => "Ruby", "emoji" => " "), "topic must be an array", Writing::Topic::Invalid]
    ]
  end

  def assert_frontmatter_preflight_failure(name:, data:, reason:, nested_cause:, environment:)
    root = Sitepress::Node.new
    post = add_resource(
      root,
      "app/content/pages/writing/posts/2000-01-01-preflight-post.markerb",
      "title" => "Preflight post",
      "topic" => ["Ruby"]
    )
    draft = add_resource(
      root,
      "app/content/pages/writing/drafts/preflight-draft",
      "title" => "Preflight draft",
      "topic" => ["Hotwire"]
    )
    source_path = "app/content/pages/writing/posts/2000-01-02-#{name}.markerb"
    add_resource(root, source_path, data)
    tree_before = tree_snapshot(root)

    error = assert_raises(Writing::ResourcePipeline::Invalid) do
      process(root, environment:)
    end

    assert_equal "Invalid writing frontmatter in #{source_path.inspect}: #{reason}", error.message
    assert_instance_of Writing::Frontmatter::Invalid, error.cause
    assert_instance_of nested_cause, error.cause.cause if nested_cause
    assert_equal tree_before, tree_snapshot(root)
    assert_same post, root.get("/writing/posts/2000-01-01-preflight-post")
    assert_nil post.data["publish_at"]
    assert_same draft, root.get("/writing/drafts/preflight-draft")
    assert_nil root.get("/writing/preflight-post")
    assert_nil root.get("/writing/topics/ruby")
    assert_nil root.get("/writing/topics/hotwire")
  end

  def add_resource(root, source_path, data = nil)
    source = Sitepress::Page.new(path: source_path)
    source.data = data || {"title" => "Example", "topic" => ["Ruby"]}

    kind, filename = source_path.match(%r{/writing/(posts|drafts)/([^/]+)\z}).captures
    path = Sitepress::Path.new(filename)
    node = root.child("writing").child(kind).child(path.node_name)

    node.resources.add Sitepress::Resource.new(
      source: source,
      node: node,
      format: path.format || node.default_format
    )
  end

  def add_resource_at(root, source_path, request_path, data = nil)
    source = Sitepress::Page.new(path: source_path)
    source.data = data || {"title" => "Example", "topic" => ["Ruby"]}
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
        [
          resource.object_id,
          resource.request_path,
          resource.source.object_id,
          resource.source.class.name,
          resource.source.path.to_s,
          resource.format,
          resource.handler,
          resource.mime_type.to_s,
          snapshot_data(resource.data)
        ]
      end,
      children: node.children.to_h do |child|
        [child.name, tree_snapshot(child)]
      end
    }
  end

  def snapshot_data(value)
    case value
    when Sitepress::Data::Record, Hash
      value.to_h.to_h { |key, member| [key, snapshot_data(member)] }
    when Sitepress::Data::Collection, Array
      value.to_a.map { snapshot_data(_1) }
    else
      value
    end
  end
end
