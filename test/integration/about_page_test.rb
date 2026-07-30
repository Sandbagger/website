require "test_helper"

class AboutPageTest < ActionDispatch::IntegrationTest
  test "about connects existing identity to the emerging direction" do
    get "/about"

    assert_response :success
    assert_select "h1", text: "About"
    assert_includes response.body, "Brit in Brussels"
    assert_includes response.body, "master"
    assert_includes response.body, "international relations"
    assert_includes response.body, "agentic"
    assert_includes response.body, "European technology"
  end
end
