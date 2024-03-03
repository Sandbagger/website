require "test_helper"

class HitControllerTest < ActionDispatch::IntegrationTest
  test "should get hit" do
    get hit_handle_url
    assert_response :success
  end
end
