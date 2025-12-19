require "test_helper"

class FeedControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get feed_index_url(format: :xml)
    assert_response :success
    assert_includes response.content_type, "xml"
    assert_includes response.body, "<rss"
  end
end
