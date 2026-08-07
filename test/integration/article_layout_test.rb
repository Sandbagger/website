require "test_helper"

class ArticleLayoutTest < ActionDispatch::IntegrationTest
  PATH = "/writing/pettis-good-tariffs-vs-bad"

  test "article header keeps title metadata and decorative cover together" do
    get PATH
    assert_response :success
    assert_select "header.article-header", 1 do
      assert_select "h1", text: "Michael Pettis on Good Tariffs vs Bad"
      assert_select ".article-meta", text: /Macroeconomics/
      assert_select ".article-meta", text: /12 October 2025/

      images = css_select("img.article-cover")

      assert_equal 1, images.size

      image = images[0]

      assert_equal "/images/posts/pettis-good-tariffs-vs-bad-1200w.webp", image["src"]
      assert_equal [
        "/images/posts/pettis-good-tariffs-vs-bad-480w.webp 480w",
        "/images/posts/pettis-good-tariffs-vs-bad-768w.webp 768w",
        "/images/posts/pettis-good-tariffs-vs-bad-1200w.webp 1200w"
      ].join(", "), image["srcset"]
      assert_equal "(max-width: 48rem) min(calc(100vw - clamp(2.2rem, 8vw, 6rem)), 36rem), 22rem", image["sizes"]
      assert_equal "1200", image["width"]
      assert_equal "630", image["height"]
      assert_equal "", image["alt"]
    end
  end

  test "article body uses a facts rail and prose column" do
    get PATH
    assert_select ".article-shell", 1 do
      assert_select "aside.article-facts", 1
      assert_select "article.prose", 1
      assert_select "article.prose h2", minimum: 1
    end
  end

  test "introductory markdown remains in the article body" do
    get PATH
    assert_select "header.article-header > p", 0
    assert_select "article.prose", text: /prompted me to write this/
  end

  test "article prose is labelled by its title" do
    get PATH

    assert_select "h1#article-title", text: "Michael Pettis on Good Tariffs vs Bad"
    assert_select "article.prose[aria-labelledby='article-title']", 1
  end
end
