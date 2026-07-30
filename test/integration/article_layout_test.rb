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
      assert_select "img.article-cover[alt='']", 1
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
end
