require "application_system_test_case"

class EditorialLayoutTest < ApplicationSystemTestCase
  PETTIS_PATH = "/writing/pettis-good-tariffs-vs-bad"

  setup do
    page.current_window.resize_to(1400, 1400)
  end

  test "homepage uses an editorial responsive grid without horizontal overflow" do
    visit "/"

    assert_equal "rgb(242, 234, 219)", evaluate_script("getComputedStyle(document.body).backgroundColor")
    assert_operator grid_column_count(".home-hero"), :>, 1

    page.current_window.resize_to(375, 900)

    assert_equal 1, grid_column_count(".home-hero")
    assert_equal 1, grid_column_count(".writing-collection--home")
    assert_no_horizontal_overflow
  end

  test "article facts collapse on small screens without horizontal overflow" do
    visit PETTIS_PATH

    refute_equal "none", display_value(".article-facts")

    page.current_window.resize_to(375, 900)

    assert_equal "none", display_value(".article-facts")
    assert_no_horizontal_overflow
  end

  test "text-only article headers collapse to one column" do
    visit PETTIS_PATH

    execute_script(<<~JAVASCRIPT)
      document.querySelector(".article-cover-frame").remove()
      document.querySelector(".article-header").classList.add("article-header--text-only")
    JAVASCRIPT

    assert_equal 1, grid_column_count(".article-header")
    assert_no_horizontal_overflow
  end

  private

  def grid_column_count(selector)
    evaluate_script(<<~JAVASCRIPT).split.length
      getComputedStyle(document.querySelector(#{selector.to_json})).gridTemplateColumns
    JAVASCRIPT
  end

  def display_value(selector)
    evaluate_script(<<~JAVASCRIPT)
      getComputedStyle(document.querySelector(#{selector.to_json})).display
    JAVASCRIPT
  end

  def assert_no_horizontal_overflow
    scroll_width, inner_width = evaluate_script(<<~JAVASCRIPT)
      [document.documentElement.scrollWidth, window.innerWidth]
    JAVASCRIPT

    assert_operator scroll_width, :<=, inner_width
  end
end
