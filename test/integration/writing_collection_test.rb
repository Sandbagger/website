require "test_helper"

class WritingCollectionTest < ActionDispatch::IntegrationTest
  test "home features the latest resource and limits compact rows to three" do
    get root_url

    assert_response :success
    assert_select "section.writing-collection--home", 1
    assert_select "article.writing-feature", 1 do
      assert_select(
        "a[href='/writing/pettis-good-tariffs-vs-bad']",
        text: /Michael Pettis/
      )
    end
    assert_select ".writing-collection--home .article-row", 3
    assert_select "a[href='/writing']", text: /archive/i
  end

  test "writing archive uses compact rows without a feature" do
    get "/writing"

    assert_response :success
    assert_select "section.writing-collection--archive", 1
    assert_select "section.writing-collection--archive > h2", text: "All writing"
    assert_select "article.writing-feature", 0
    assert_select ".writing-collection--archive .article-row", 4
  end

  test "writing archive is in descending publication order" do
    get "/writing"

    document = Nokogiri::HTML5(response.body)
    paths = document.css(
      ".writing-collection--archive .article-row h3 a"
    ).map { |link| link["href"] }

    assert_equal [
      "/writing/pettis-good-tariffs-vs-bad",
      "/writing/capture-request-referrer-via-css",
      "/writing/tag-overriding-in-phlex-and-markdown",
      "/writing/markdown-in-rails-with-phlex-and-sitepress"
    ], paths
  end

  test "article tail uses more writing and excludes the current resource" do
    path = "/writing/markdown-in-rails-with-phlex-and-sitepress"
    get path

    assert_response :success
    assert_select "section.writing-collection--more", 1
    assert_select "h2", text: "More writing"
    assert_select "a[href='#{path}']", 0
  end
end
