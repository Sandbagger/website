require "test_helper"

class WritingCollectionTest < ActionDispatch::IntegrationTest
  PHYSICAL_POSTS = {
    "/writing/markdown-in-rails-with-phlex-and-sitepress" =>
      "2024-02-27-markdown-in-rails-with-phlex-and-sitepress.html.markerb",
    "/writing/tag-overriding-in-phlex-and-markdown" =>
      "2024-03-03-tag-overriding-in-phlex-and-markdown.html.markerb",
    "/writing/pettis-good-tariffs-vs-bad" =>
      "2025-10-12-pettis-good-tariffs-vs-bad.markerb"
  }.freeze

  test "home features the latest resource and limits compact rows to three" do
    get root_url

    assert_response :success
    assert_select "section.writing-collection--home", 1
    assert_select "article.writing-feature", 1 do
      assert_select(
        "a.writing-feature__cover[aria-label='Read Michael Pettis on Good Tariffs vs Bad']",
        1
      ) do
        assert_select(
          "img[src='/images/posts/pettis-good-tariffs-vs-bad.webp'][width='1200'][height='630'][alt='']",
          1
        )
      end
      assert_select(
        "a[href='/writing/pettis-good-tariffs-vs-bad']",
        text: /Michael Pettis/
      )
    end
    assert_select ".writing-collection--home .article-row", PHYSICAL_POSTS.size - 1
    assert_select "a[href='/writing']", text: /archive/i
  end

  test "writing archive uses compact rows without a feature" do
    get "/writing"

    assert_response :success
    assert_select "section.writing-collection--archive", 1
    assert_select "section.writing-collection--archive > h2", text: "All writing"
    assert_select "article.writing-feature", 0
    assert_select ".writing-collection--archive .article-row", PHYSICAL_POSTS.size
  end

  test "writing archive is in descending publication order" do
    get "/writing"

    document = Nokogiri::HTML5(response.body)
    paths = document.css(
      ".writing-collection--archive .article-row h3 a"
    ).map { |link| link["href"] }

    assert_equal [
      "/writing/pettis-good-tariffs-vs-bad",
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

  test "published resources retain canonical paths backed by dated post files" do
    PHYSICAL_POSTS.each do |request_path, filename|
      resource = Sitepress.site.get(request_path)

      assert resource, "Expected #{request_path} to resolve"
      assert resource.source.path.to_s.end_with?("/writing/posts/#{filename}")
    end
  end

  test "writing front matter contains no legacy publication keys" do
    paths = Rails.root.glob("app/content/pages/writing/**/*").select(&:file?)

    paths.each do |path|
      assert_no_match(
        /^(?:status|published|publish_at):/,
        path.read,
        "Legacy publication metadata remains in #{path}"
      )
    end
  end
end
