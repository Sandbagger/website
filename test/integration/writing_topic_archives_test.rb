# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

class WritingTopicArchivesTest < ActionDispatch::IntegrationTest
  MutableClock = Struct.new(:now) do
    def today = Writing::PublicationClock.new.today(at: now)
  end

  test "a generated topic resource renders its published posts newest first" do
    resource = Sitepress.site.get("/writing/topics/phlex")

    assert_instance_of Sitepress::Resource, resource
    assert_instance_of Writing::TopicPage, resource.source
    assert_equal "/writing/topics/phlex", resource.request_path

    get resource.request_path

    assert_response :success
    assert_select "main.page--archive", 1
    assert_select "h1", text: "Writing about Phlex"

    document = Nokogiri::HTML5(response.body)
    paths = document.css(
      ".writing-collection--archive .article-row h3 a"
    ).map { |link| link["href"] }

    assert_equal [
      "/writing/tag-overriding-in-phlex-and-markdown",
      "/writing/markdown-in-rails-with-phlex-and-sitepress"
    ], paths
    assert_not_includes response.body, "Why I made this site with Phlex"
    assert_not_includes response.body, "Michael Pettis on Good Tariffs vs Bad"
  end

  test "a generated draft-only topic resource is unavailable" do
    resource = Sitepress.site.get("/writing/topics/css")

    assert_instance_of Sitepress::Resource, resource
    assert_instance_of Writing::TopicPage, resource.source

    get resource.request_path

    assert_response :not_found
  end

  test "a scheduled-only topic becomes available at Brussels midnight without rebuilding" do
    clock = MutableClock.new(Time.utc(2026, 8, 9, 21, 59, 59))

    with_scheduled_topic_site do |site, resource|
      with_publication_dependencies(clock:, environment: "production") do
        get resource.request_path

        assert_response :not_found
        assert_same resource, site.get(resource.request_path)

        clock.now = Time.utc(2026, 8, 9, 22, 0)
        get resource.request_path

        assert_response :success
        assert_select "h1", text: "Writing about Scheduled"
        assert_select "a[href='/writing/midnight']", text: "Midnight"
        assert_same resource, site.get(resource.request_path)
      end
    end
  end

  private

  def with_scheduled_topic_site
    original_site = Sitepress.site
    original_cache_resources = Sitepress.configuration.cache_resources
    Sitepress.configuration.cache_resources = true

    Dir.mktmpdir("writing-topic-archives") do |directory|
      site = build_scheduled_site(directory)
      Sitepress.configuration.site = site
      resource = site.get("/writing/topics/scheduled")

      assert_instance_of Sitepress::Resource, resource
      assert_instance_of Writing::TopicPage, resource.source
      yield site, resource
    ensure
      Sitepress.configuration.site = original_site
    end
  ensure
    Sitepress.configuration.cache_resources = original_cache_resources
  end

  def build_scheduled_site(directory)
    post_path = File.join(
      directory,
      "pages/writing/posts/2026-08-10-midnight.markerb"
    )
    template_path = File.join(directory, "templates/topic.markerb")
    FileUtils.mkdir_p(File.dirname(post_path))
    FileUtils.mkdir_p(File.dirname(template_path))
    File.write(
      post_path,
      "---\ntitle: Midnight\ntopic:\n  - Scheduled\n---\nScheduled body\n"
    )
    File.write(
      template_path,
      "<!-- Topic archive rows are supplied by the controller. -->\n"
    )
    write_navigation_pages(directory)

    Sitepress::Site.new(root_path: directory).tap do |site|
      pipeline = Writing::ResourcePipeline.new(
        environment: "production",
        pages_path: site.pages_path,
        topic_template_path: template_path
      )
      site.manipulate { |root| pipeline.process(root) }
    end
  end

  def write_navigation_pages(directory)
    %w[Home Writing About].each do |title|
      filename = (title == "Home") ? "index" : title.downcase
      File.write(
        File.join(directory, "pages/#{filename}.markerb"),
        "---\ntitle: #{title}\n---\n#{title}\n"
      )
    end
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
