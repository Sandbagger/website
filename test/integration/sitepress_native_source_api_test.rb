# frozen_string_literal: true

require "test_helper"

class SitepressNativeSourceApiTest < ActiveSupport::TestCase
  SOURCE_FILES = Rails.root.glob("{app,lib,test}/**/*.{rb,rake}")
    .reject { |path| path.basename.to_s == "sitepress_native_source_api_test.rb" }
    .freeze
  LEGACY_PATTERNS = {
    "Sitepress asset constant" => /Sitepress::A(?:sset)/,
    "resource asset reader" => /\.a(?:sset)\b/,
    "resource asset keyword" => /\ba(?:sset):/
  }.freeze

  test "application and tests use only Sitepress 5 source APIs" do
    violations = SOURCE_FILES.flat_map do |path|
      source = path.read
      LEGACY_PATTERNS.filter_map do |label, pattern|
        "#{path.relative_path_from(Rails.root)}: #{label}" if source.match?(pattern)
      end
    end

    assert_empty violations, violations.join("\n")
  end
end
