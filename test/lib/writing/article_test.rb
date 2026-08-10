# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/writing/frontmatter")
require Rails.root.join("lib/writing/article")

class Writing::ArticleTest < ActiveSupport::TestCase
  FACADE = %i[
    draft? emoji post? publication_date request_path slug source_path title topics url
  ].freeze

  test "projects every post reader from its physical path and frontmatter" do
    source_path = "app/content/pages/writing/posts/2024-03-10-example.markerb"
    article = Writing::Article.from(resource("/temporary", source_path, valid_data))

    assert_equal "Example", article.title
    assert_equal ["Ruby", "Phlex"], article.topics.map(&:label)
    assert_equal "🦄", article.emoji
    assert_equal Date.new(2024, 3, 10), article.publication_date
    assert_predicate article, :post?
    assert_not_predicate article, :draft?
    assert_equal "example", article.slug
    assert_equal source_path, article.source_path
    assert_equal "/writing/example", article.request_path
    assert_equal "/writing/example", article.url
  end

  test "projects every draft reader from its physical path and frontmatter" do
    source_path = "app/content/pages/writing/drafts/example.markerb"
    data = valid_data.merge("title" => "Draft", "topic" => ["Hotwire"], "emoji" => nil)
    article = Writing::Article.from(resource("/temporary", source_path, data))

    assert_equal "Draft", article.title
    assert_equal ["Hotwire"], article.topics.map(&:label)
    assert_nil article.emoji
    assert_nil article.publication_date
    assert_predicate article, :draft?
    assert_not_predicate article, :post?
    assert_equal "example", article.slug
    assert_equal source_path, article.source_path
    assert_equal "/writing/drafts/example", article.request_path
    assert_equal "/writing/drafts/example", article.url
  end

  test "is a frozen identity object" do
    sitepress_resource = resource(
      "/temporary",
      "app/content/pages/writing/posts/2024-03-10-example.markerb",
      valid_data
    )

    first = Writing::Article.from(sitepress_resource)
    second = Writing::Article.from(sitepress_resource)
    articles = {first => :first, second => :second}

    assert_instance_of Writing::Article, first
    assert_kind_of Literal::Object, first
    assert_predicate first, :frozen?
    refute_same first, second
    refute_equal first, second
    refute first.eql?(second)
    assert_equal({first => :first, second => :second}, articles)
    assert_equal 2, articles.size
    assert_equal first.hash, first.hash
    assert_equal second.hash, second.hash
  end

  test "exposes only the explicit domain facade and keeps projections private" do
    article = Writing::Article.from(
      resource(
        "/temporary",
        "app/content/pages/writing/posts/2024-03-10-example.markerb",
        valid_data
      )
    )

    assert_equal FACADE, Writing::Article.public_instance_methods(false).sort
    assert Writing::Article.private_method_defined?(:path)
    assert Writing::Article.private_method_defined?(:frontmatter)
    assert_raises(NoMethodError) { article.path }
    assert_raises(NoMethodError) { article.frontmatter }
    refute_respond_to article, :data
    refute_respond_to article, :resource
    refute_respond_to article, :source
    refute_respond_to article, :fetch_data
    refute_respond_to article, :to_h
    refute_respond_to article, :to_hash
    refute_respond_to article, :as_json
    refute_respond_to article, :to_json
    refute_includes Writing::Article.instance_methods(false), :method_missing
  end

  test "rejects generic hash conversion" do
    article = Writing::Article.from(
      resource(
        "/temporary",
        "app/content/pages/writing/posts/2024-03-10-example.markerb",
        valid_data
      )
    )

    assert_raises(TypeError) { Hash(article) }
  end

  test "rejects direct and Active Support JSON serialization" do
    article = Writing::Article.from(
      resource(
        "/temporary",
        "app/content/pages/writing/posts/2024-03-10-example.markerb",
        valid_data
      )
    )

    assert_raises(NoMethodError) { article.as_json }
    assert_raises(NoMethodError) { article.to_json }
    assert_raises(NoMethodError) { ActiveSupport::JSON.encode(article) }
  end

  test "Ruby JSON generation exposes only the opaque object string" do
    article = Writing::Article.from(
      resource(
        "/temporary",
        "app/content/pages/writing/posts/2024-03-10-example.markerb",
        valid_data
      )
    )

    json = JSON.generate(article)

    assert_equal article.to_s, JSON.parse(json)
    refute_includes json, "Writing::Path"
    refute_includes json, "Writing::Frontmatter"
    refute_includes json, article.source_path
    refute_includes json, article.title
    article.topics.each { refute_includes json, _1.label }
    refute_includes json, article.emoji
  end

  test "retains only the immutable path and frontmatter projections" do
    sitepress_resource = resource(
      "/temporary",
      "app/content/pages/writing/posts/2024-03-10-example.markerb",
      valid_data
    )

    article = Writing::Article.from(sitepress_resource)

    assert_equal %i[@frontmatter @path], article.instance_variables.sort
    assert_instance_of Writing::Path, article.instance_variable_get(:@path)
    assert_instance_of Writing::Frontmatter, article.instance_variable_get(:@frontmatter)
    refute_includes article.instance_variables.map { article.instance_variable_get(_1) }, sitepress_resource
  end

  test "keeps canonical paths stable when the Sitepress resource is remapped" do
    sitepress_resource = resource(
      "/temporary",
      "app/content/pages/writing/posts/2024-03-10-stable.markerb",
      valid_data
    )
    article = Writing::Article.from(sitepress_resource)
    destination = Sitepress::Node.new.child("remapped")

    sitepress_resource.node = destination

    assert_equal "/remapped", sitepress_resource.request_path
    assert_equal "/writing/stable", article.request_path
    assert_equal "/writing/stable", article.url
  end

  test "owns frontmatter values independently from mutable Sitepress data" do
    title = +"Example"
    first_topic = +"Ruby"
    second_topic = +"Phlex"
    source_topics = [first_topic, second_topic]
    emoji = +"🦄"
    source_data = {"title" => title, "topic" => source_topics, "emoji" => emoji}
    sitepress_resource = resource(
      "/temporary",
      "app/content/pages/writing/posts/2024-03-10-example.markerb",
      source_data
    )
    article = Writing::Article.from(sitepress_resource)

    title << " changed"
    first_topic << " changed"
    second_topic << " changed"
    source_topics.clear
    emoji << " changed"
    sitepress_resource.data["title"] = "Replaced"
    sitepress_resource.data["topic"] = ["Changed"]
    sitepress_resource.data["emoji"] = "Changed"

    assert_equal "Example", article.title
    assert_equal ["Ruby", "Phlex"], article.topics.map(&:label)
    assert_equal "🦄", article.emoji
    refute_predicate title, :frozen?
    refute_predicate first_topic, :frozen?
    refute_predicate second_topic, :frozen?
    refute_predicate source_topics, :frozen?
    refute_predicate emoji, :frozen?
  end

  test "enforces the typed projection properties" do
    path = Writing::Path.new(
      "app/content/pages/writing/posts/2024-03-10-example.markerb"
    )
    frontmatter = Writing::Frontmatter.from(
      Sitepress::Data.manage(valid_data),
      source_path: path.source_path
    )

    assert_raises(Literal::TypeError) do
      Writing::Article.new(path: Object.new, frontmatter:)
    end
    assert_raises(Literal::TypeError) do
      Writing::Article.new(path:, frontmatter: Object.new)
    end
  end

  test "propagates path errors without constructing an article" do
    sitepress_resource = resource(
      "/temporary",
      "app/content/pages/writing/posts/example.markerb",
      valid_data
    )

    error = assert_raises(Writing::Path::Invalid) do
      Writing::Article.from(sitepress_resource)
    end

    assert_equal(
      "Invalid writing path \"app/content/pages/writing/posts/example.markerb\": " \
        "is missing a publication date",
      error.message
    )
  end

  test "propagates frontmatter errors with the physical source path" do
    source_path = "app/content/pages/writing/posts/2024-03-10-example.markerb"
    sitepress_resource = resource(
      "/temporary",
      source_path,
      valid_data.except("title")
    )

    error = assert_raises(Writing::Frontmatter::Invalid) do
      Writing::Article.from(sitepress_resource)
    end

    assert_equal(
      "Invalid writing frontmatter in #{source_path.inspect}: missing title metadata",
      error.message
    )
  end

  private

  def valid_data
    {"title" => "Example", "topic" => ["Ruby", "Phlex"], "emoji" => "🦄"}
  end

  def resource(request_path, source_path, data)
    root = Sitepress::Node.new
    path = Sitepress::Path.new(request_path)
    node = path.node_names.reduce(root) { |parent, name| parent.child(name) }
    source = Sitepress::Page.new(path: source_path)
    source.data = data

    node.resources.add Sitepress::Resource.new(
      source:,
      node:,
      format: path.format || node.default_format
    )
  end
end
