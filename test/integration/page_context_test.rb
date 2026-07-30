require "test_helper"

class PageContextTest < ActionDispatch::IntegrationTest
  test "home uses the home context" do
    get root_url
    assert_select "main.page--home", 1
  end

  test "writing index uses the archive context" do
    get "/writing"
    assert_select "main.page--archive", 1
  end

  test "a writing resource uses the article context" do
    get "/writing/pettis-good-tariffs-vs-bad"
    assert_select "main.page--article", 1
  end

  test "about uses the default context" do
    get "/about"
    assert_select "main.page--default", 1
  end
end
