# frozen_string_literal: true

require "test_helper"
require "fastimage"

class Writing::CoverAssetsTest < ActiveSupport::TestCase
  EXPECTED = %w[
    capture-request-referrer-via-css
    embrace_the_cascade_in_your_rails_app
    markdown-in-rails-with-phlex-and-sitepress
    national-accounting
    pettis-good-tariffs-vs-bad
    tag-overriding-in-phlex-and-markdown
    why-I-made-this-site-with-phlex-sitepress-and-rails
  ].freeze

  test "repository contains canonical dimensioned WebP covers" do
    root = Rails.root.join("public/images/posts")
    webps = root.glob("*.webp")

    assert_equal EXPECTED, webps.map { _1.basename(".webp").to_s }.sort
    webps.each do |path|
      image = Sitepress::Image.new(path: path)

      assert_equal :webp, FastImage.type(path.to_s), path.to_s
      assert_equal [1200, 630], [image.width, image.height], path.to_s
    end
  end
end
