require "test_helper"

class PagesSmokeTest < ActionDispatch::IntegrationTest
  PUBLISHED_WRITING_PATHS = %w[
    /writing/markdown-in-rails-with-phlex-and-sitepress
    /writing/tag-overriding-in-phlex-and-markdown
    /writing/pettis-good-tariffs-vs-bad
  ].freeze

  Sitepress.site.resources.each do |resource|
    next unless resource.mime_type.to_s.include?("html")
    next if resource.source.is_a?(Writing::TopicPage)

    test "renders #{resource.request_path}" do
      get resource.request_path
      assert_response :success,
        "#{resource.request_path} returned #{response.status}\n#{response.body.to_s[0, 500]}"
    end
  end

  test "published writing keeps its stable public paths" do
    PUBLISHED_WRITING_PATHS.each do |path|
      get path

      assert_response :success, "#{path} returned #{response.status}"
    end
  end

  test "physical dated post paths are not routable" do
    get "/writing/posts/2024-03-10-capture-request-referrer-via-css"

    assert_response :not_found
  end
end
