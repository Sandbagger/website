require "test_helper"

class HitTrackingRemovalTest < ActionDispatch::IntegrationTest
  test "the legacy hit endpoint is unavailable" do
    get "/hit/handle"

    assert_response :not_found
  end
end
