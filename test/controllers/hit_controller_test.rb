require "test_helper"
require "securerandom"

class HitsControllerTest < ActionDispatch::IntegrationTest
  include Mocktail::DSL  # Ensure DSL is included if not globally available
  def setup
    Hit.delete_all  # Ensuring each test starts with a clean slate
    # Replace SecureRandom with a mock and stub the hex method

    Mocktail.replace(SecureRandomWrapper)
    stubs { SecureRandomWrapper.hex(10) }.with { "117bc6a90d678355f46a" }
  end

  test "sets a unique id cookie for a new visitor" do
    get hit_handle_url

    assert_response :success
    assert_equal "117bc6a90d678355f46a", cookies[:unique_id], "The unique_id cookie should be set correctly"
  end

  # cache headers are set to ensure that the tracking pixel is cached for the day
  # so we assume that every request should be a new hit on a new day
  test "should create a hit on" do
    assert_difference("Hit.count", 1) do
      get hit_handle_url, params: {page_id: "home"}, headers: {HTTP_REFERER: "http://example.com", HTTP_USER_AGENT: "Mozilla/5.0"}
    end
    assert_response :success
  end
end
