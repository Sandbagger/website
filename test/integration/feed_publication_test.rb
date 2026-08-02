# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

class FeedPublicationTest < ActionDispatch::IntegrationTest
  test "feed includes due posts and excludes drafts" do
    get feed_index_url(format: :xml)

    assert_response :success
    assert_includes response.body, "Michael Pettis on Good Tariffs vs Bad"
    assert_includes response.body, "Capture Request Referrer via CSS"
    assert_not_includes response.body, "Embrace the cascade in your Rails app"
    assert_not_includes response.body, "Interesting Tailwind vs Semantic CSS Artical"
  end

  test "feed membership follows physical publication paths and dates" do
    with_publication_site do
      get feed_index_url(format: :xml)

      assert_response :success
      assert_includes response.body, "Due feed post"
      assert_not_includes response.body, "Scheduled feed post"
      assert_not_includes response.body, "Draft feed post"
    end
  end

  private

  def with_publication_site
    controller = FeedController
    original_resources = controller.writing_publication_resources

    Dir.mktmpdir("feed-publication") do |directory|
      controller.writing_publication_resources = build_site(directory).resources
      yield
    ensure
      controller.writing_publication_resources = original_resources
    end
  end

  def build_site(directory)
    write_resource(directory, "posts/2000-01-01-due.markerb", "Due feed post")
    write_resource(directory, "posts/2999-01-01-scheduled.markerb", "Scheduled feed post")
    write_resource(directory, "drafts/draft.markerb", "Draft feed post")

    Sitepress::Site.new(root_path: directory).tap do |site|
      pipeline = Writing::ResourcePipeline.new(
        environment: "test",
        pages_path: site.pages_path
      )
      site.manipulate { |root| pipeline.process(root) }
    end
  end

  def write_resource(directory, relative_path, title)
    path = File.join(directory, "pages", "writing", relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "---\ntitle: #{title}\n---\nBody\n")
  end
end
