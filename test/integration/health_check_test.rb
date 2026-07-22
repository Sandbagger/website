require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "reports that the application is up" do
    get "/up"

    assert_response :success
  end
end
