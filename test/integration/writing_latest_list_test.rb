require "test_helper"

class WritingLatestListTest < ActionDispatch::IntegrationTest
  test "latest list excludes current post" do
    path = "/writing/markdown-in-rails-with-phlex-and-sitepress"
    get path
    assert_response :success
    assert_includes @response.body, "Latest"
    assert_not_includes @response.body, %(href="#{path}")
  end
end
