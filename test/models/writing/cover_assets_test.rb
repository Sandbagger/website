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
  SIZES = {480 => 252, 768 => 403, 1200 => 630}.freeze

  test "repository contains only canonical responsive lossless WebP covers" do
    root = Rails.root.join("public/images/posts")
    expected = EXPECTED.product(SIZES.keys).map { |slug, width| "#{slug}-#{width}w.webp" }.sort
    covers = root.children.select(&:file?)

    assert_equal expected, covers.map { _1.basename.to_s }.sort
    covers.each do |path|
      width = path.basename.to_s.match(/-(480|768|1200)w\.webp\z/)[1].to_i
      image = Sitepress::Image.new(path: path)

      assert_equal :webp, FastImage.type(path.to_s), path.to_s
      assert_equal "VP8L", path.binread(4, 12), path.to_s
      assert_equal [width, SIZES.fetch(width)], [image.width, image.height], path.to_s
    end
  end
end
