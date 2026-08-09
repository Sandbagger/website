# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

class WritingPublicationAccessTest < ActionDispatch::IntegrationTest
  MutableClock = Struct.new(:now) do
    def today = Writing::PublicationClock.new.today(at: now)
  end

  test "a scheduled resource becomes available at Brussels midnight without rebuilding" do
    clock = MutableClock.new(Time.utc(2026, 7, 31, 21, 59, 59))

    with_scheduled_resource do |resource|
      with_publication_dependencies(clock:, environment: "production") do
        get resource.request_path
        assert_response :not_found
        assert_same resource, Sitepress.site.get(resource.request_path)

        clock.now = Time.utc(2026, 7, 31, 22, 0)
        get resource.request_path
        assert_response :success
        assert_same resource, Sitepress.site.get(resource.request_path)
      end
    end
  end

  test "draft previews use the article layout while the archive does not" do
    with_draft_resource do |resource|
      get resource.request_path

      assert_response :success
      assert_select "main.page--article", 1
    end

    get "/writing"

    assert_response :success
    assert_select "main.page--archive", 1
    assert_select "main.page--article", 0
  end

  test "the actual extensionless draft renders as an article preview" do
    get "/writing/drafts/tailwind-vs-semantic-css"

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "main.page--article", 1
    assert_select "h1#article-title", text: "Interesting Tailwind vs Semantic CSS Artical"
    assert_select "article.prose h1", text: "Tailwind vs Semantic CSS"
    assert_includes response.body, "two implementations side by side"
    assert_not_includes response.body, "topic:\n  - CSS"
  end

  private

  def with_draft_resource
    with_temporary_resource(
      "writing/drafts/preview.markerb",
      "/writing/drafts/preview"
    ) { |resource| yield resource }
  end

  def with_scheduled_resource
    with_temporary_resource(
      "writing/posts/2026-08-01-midnight.markerb",
      "/writing/midnight"
    ) do |resource|
      resource.data["publish_at"] = Date.new(2026, 8, 1)
      yield resource
    end
  end

  def with_temporary_resource(source_name, request_path)
    original_cache_resources = Sitepress.configuration.cache_resources
    Sitepress.configuration.cache_resources = true

    Dir.mktmpdir("writing-publication-access") do |directory|
      source_path = File.join(directory, source_name)
      FileUtils.mkdir_p(File.dirname(source_path))
      File.write(source_path, "---\ntitle: Preview\n---\nPreview body\n")

      source = Sitepress::Page.new(path: source_path)
      path = Sitepress::Path.new(request_path)
      node = path.node_names.reduce(Sitepress.site.root) do |parent, name|
        parent.child(name)
      end
      resource = node.resources.add Sitepress::Resource.new(
        source: source,
        node: node,
        format: :html
      )

      yield resource
    ensure
      resource&.remove
    end
  ensure
    Sitepress.configuration.cache_resources = original_cache_resources
  end

  def with_publication_dependencies(clock:, environment:)
    controller = Sitepress::SiteController
    original_clock = controller.writing_publication_clock
    original_environment = controller.writing_publication_environment
    controller.writing_publication_clock = clock
    controller.writing_publication_environment = environment

    yield
  ensure
    controller.writing_publication_clock = original_clock
    controller.writing_publication_environment = original_environment
  end
end
