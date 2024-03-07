require "test_helper"

class HitControllerTest < ActionDispatch::IntegrationTest
  test "should get hit" do
    get hit_handle_url
    assert_response :success
    assert_equal "image/gif", @response.content_type
    assert_equal "inline", @response.headers["Content-Disposition"].split(";").first
    expected_pixel_data = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/8AARgAsAmploiAAAAAASUVORK5CYII=")
    assert_equal expected_pixel_data, @response.body
  end
end
