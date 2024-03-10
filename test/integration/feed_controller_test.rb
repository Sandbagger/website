require 'test_helper'

class FeedControllerTest < ActionDispatch::IntegrationTest
  test "should get index and return XML" do
    get feed_index_url
    assert_response :success
    assert_equal "application/xml; charset=utf-8", @response.content_type
  end
end