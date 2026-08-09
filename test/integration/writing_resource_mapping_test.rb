# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

class WritingResourceMappingTest < ActiveSupport::TestCase
  POSTS = {
    "2024-02-27-markdown-in-rails-with-phlex-and-sitepress.html.markerb" =>
      "/writing/markdown-in-rails-with-phlex-and-sitepress",
    "2024-03-03-tag-overriding-in-phlex-and-markdown.html.markerb" =>
      "/writing/tag-overriding-in-phlex-and-markdown",
    "2024-03-10-capture-request-referrer-via-css.html.markerb" =>
      "/writing/capture-request-referrer-via-css",
    "2025-10-12-pettis-good-tariffs-vs-bad.markerb" =>
      "/writing/pettis-good-tariffs-vs-bad"
  }.freeze

  test "maps dated physical resources to stable Sitepress request paths" do
    with_temporary_site do
      POSTS.each do |filename, request_path|
        resource = Sitepress.site.get(request_path)

        assert resource, "Expected #{request_path} to resolve"
        assert_equal request_path, resource.request_path
        assert resource.source.path.to_s.end_with?("/writing/posts/#{filename}")
      end

      assert_nil Sitepress.site.get(
        "/writing/posts/2024-03-10-capture-request-referrer-via-css"
      )
    end
  end

  test "maps canonical topic metadata to native topic resources" do
    with_temporary_site do
      resource = Sitepress.site.get("/writing/topics/ruby")

      assert_instance_of Sitepress::Resource, resource
      assert_instance_of Writing::TopicPage, resource.source
      assert_equal :html, resource.format
      assert_equal :markerb, resource.handler
      assert_equal "text/html", resource.mime_type.to_s
    end
  end

  private

  def with_temporary_site
    original_site = Sitepress.site

    Dir.mktmpdir("writing-resource-mapping") do |directory|
      site = build_site(directory)
      Sitepress.configuration.site = site
      yield
    ensure
      Sitepress.configuration.site = original_site
    end
  end

  def build_site(directory)
    posts_path = File.join(directory, "pages", "writing", "posts")
    topic_template_path = File.join(directory, "templates", "topic.markerb")
    FileUtils.mkdir_p(posts_path)
    FileUtils.mkdir_p(File.dirname(topic_template_path))
    File.write(topic_template_path, "<!-- Topic archive rows are supplied by the controller. -->\n")

    POSTS.each_key do |filename|
      File.write(File.join(posts_path, filename), "---\ntitle: Example\ntopic:\n  - Ruby\n---\nBody\n")
    end

    Sitepress::Site.new(root_path: directory).tap do |site|
      pipeline = Writing::ResourcePipeline.new(
        environment: "test",
        pages_path: site.pages_path,
        topic_template_path: topic_template_path
      )
      site.manipulate { |root| pipeline.process(root) }
    end
  end
end
