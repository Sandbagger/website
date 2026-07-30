require "test_helper"

class SiteChromeTest < ActionDispatch::IntegrationTest
  test "shared chrome lives inside the body with valid landmarks" do
    get root_url

    assert_response :success
    assert_select "body > header.site-header", 1
    assert_select "body > main.site-main", 1
    assert_select "body > footer.site-footer", 1
    assert_select "nav[aria-label='Primary']", 1
    assert_select "nav ul > h1, nav ul > h2, nav ul > h3", 0
    assert_select "nav ul > ul", 0
  end

  test "primary navigation includes home writing and about" do
    get root_url

    assert_select "nav[aria-label='Primary']" do
      assert_select "a[href='/']", text: "Home"
      assert_select "a[href='/writing']", text: "Writing"
      assert_select "a[href='/about']", text: "About"
    end
  end

  test "current page is visible and programmatically identified" do
    get "/about"

    assert_select "nav a.active[aria-current='page'][href='/about']", text: "About"
  end

  test "footer exposes rss and existing social profiles safely" do
    get root_url

    assert_select "footer" do
      assert_select "a[href='/feed']", text: "RSS"
      assert_select "a[href='https://ruby.social/@Sandbagger'][rel~='me'][rel~='noopener'][rel~='noreferrer']", text: "Mastodon"
      assert_select "a[href='https://bsky.app/profile/williamneal.bsky.social'][rel~='me'][rel~='noopener'][rel~='noreferrer']", text: "Bluesky"
    end
  end
end
