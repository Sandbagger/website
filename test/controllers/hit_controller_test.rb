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
    assert_equal "117bc6a90d678355f46a", cookies[:unique_id]
  end

  # cache headers are set to ensure that the tracking pixel is cached for the day
  # so we assume that every request should be a new hit on a new day
  test "should create a hit with correct attributes" do
    user_agent = "Mozilla/5.0"
    referrer = "http://example.com"
    page = "home"
    assert_difference("Hit.count", 1) do
      get hit_handle_url, params: { ref: page }, headers: { HTTP_REFERER: referrer, HTTP_USER_AGENT: user_agent }
    end

    hit = Hit.last
    assert_equal "117bc6a90d678355f46a", hit.unique_user_id
    assert_equal user_agent, hit.user_agent
    assert_equal page, hit.page
    assert_equal referrer, hit.referer
    assert_equal 'home', hit.path

    assert_response :success
  end
end
