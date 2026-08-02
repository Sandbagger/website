# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"
require "securerandom"

class WritingBootValidationTest < ActiveSupport::TestCase
  test "registers the writing resource pipeline exactly once" do
    assert_equal 1, Sitepress.site.resources_pipeline.size
    assert Sitepress.configuration.cache_resources,
      "boot subprocess isolation relies on test-environment resource caching"
  end

  test "invalid writing content aborts boot before runner code executes" do
    source_path = Rails.root.join(
      "app/content/pages/writing/posts/2000-01-01-boot-invalid-#{SecureRandom.hex(8)}.markerb"
    )
    runner_sentinel = "WRITING_RUNNER_EXECUTED"

    File.write(source_path, <<~CONTENT)
      ---
      title: Invalid boot resource
      status: draft
      ---
      Invalid boot resource
    CONTENT

    stdout, stderr, status = Open3.capture3(
      {
        "DISABLE_SPRING" => "1",
        "PARALLEL_WORKERS" => "1",
        "RAILS_ENV" => "test"
      },
      RbConfig.ruby,
      Rails.root.join("bin/rails").to_s,
      "runner",
      %(puts #{runner_sentinel.inspect}),
      chdir: Rails.root.to_s
    )
    output = stdout + stderr

    refute_predicate status, :success?, output
    assert_includes output, "Legacy writing metadata \"status\""
    assert_includes output, source_path.to_s
    refute_includes output, runner_sentinel
  ensure
    FileUtils.rm_f(source_path) if source_path
  end
end
