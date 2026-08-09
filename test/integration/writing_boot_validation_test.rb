# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"
require "securerandom"
require "tmpdir"

class WritingBootValidationTest < ActiveSupport::TestCase
  test "registers the writing resource pipeline exactly once" do
    assert_equal 1, Sitepress.site.resources_pipeline.size
    assert Sitepress.configuration.cache_resources,
      "boot subprocess isolation relies on test-environment resource caching"
  end

  test "invalid writing content aborts boot before runner code executes" do
    runner_sentinel = "WRITING_RUNNER_EXECUTED"
    stdout, stderr, status, source_path, temporary_root = capture_invalid_boot(
      runner_sentinel
    )
    output = stdout + stderr

    refute_predicate status, :success?, output
    assert_includes output, "Legacy writing metadata \"status\""
    assert_includes output, source_path.to_s
    refute_includes output, runner_sentinel
    refute_predicate temporary_root, :exist?
  end

  test "invalid topic metadata aborts boot before runner code executes" do
    runner_sentinel = "WRITING_TOPIC_RUNNER_EXECUTED"
    stdout, stderr, status, source_path, temporary_root = capture_invalid_boot(
      runner_sentinel,
      topic: "Ruby",
      metadata: nil
    )
    output = stdout + stderr

    refute_predicate status, :success?, output
    assert_includes output, "topic must be an array"
    assert_includes output, source_path.to_s
    refute_includes output, runner_sentinel
    refute_predicate temporary_root, :exist?
  end

  test "scalar-topic boot fixture contains exactly one topic key" do
    Dir.mktmpdir("writing-boot-validation") do |directory|
      temporary_root = Pathname.new(directory)
      FileUtils.mkdir_p(temporary_root.join("app/content/pages/writing/posts"))
      source_path = write_invalid_resource(temporary_root, topic: "Ruby", metadata: nil)
      contents = File.read(source_path)

      assert_equal 1, contents.lines.grep(/^topic:/).size
      assert_includes contents, "topic: Ruby"
    end
  end

  private

  SAFE_CONFIG_FILES = %w[
    application.rb
    boot.rb
    cable.yml
    database.yml
    environment.rb
    routes.rb
    storage.yml
  ].freeze
  SAFE_CONFIG_DIRECTORIES = %w[environments initializers locales].freeze

  def capture_invalid_boot(runner_sentinel, topic: ["Ruby"], metadata: "status: draft")
    temporary_root = nil
    result = Dir.mktmpdir("writing-boot-validation") do |directory|
      temporary_root = Pathname.new(directory)
      build_temporary_application(temporary_root)
      source_path = write_invalid_resource(temporary_root, topic:, metadata:)

      [
        *run_boot(temporary_root, runner_sentinel),
        source_path
      ]
    end

    [*result, temporary_root]
  end

  def build_temporary_application(temporary_root)
    copy_boot_files(temporary_root)
    link_application_code(temporary_root)
    FileUtils.cp_r(Rails.root.join("app/content"), temporary_root.join("app/content"))

    refute_path_exists temporary_root.join("config/credentials.yml.enc")
    refute_path_exists temporary_root.join("config/credentials")
    refute_path_exists temporary_root.join("config/master.key")
  end

  def copy_boot_files(temporary_root)
    FileUtils.mkdir_p(temporary_root.join("bin"))
    FileUtils.mkdir_p(temporary_root.join("config"))
    FileUtils.mkdir_p(temporary_root.join("app"))
    FileUtils.cp(Rails.root.join("bin/rails"), temporary_root.join("bin/rails"))

    SAFE_CONFIG_FILES.each do |relative_path|
      FileUtils.cp(
        Rails.root.join("config", relative_path),
        temporary_root.join("config", relative_path)
      )
    end
  end

  def link_application_code(temporary_root)
    link_paths(temporary_root, %w[Gemfile Gemfile.lock lib])
    link_paths(temporary_root.join("config"), SAFE_CONFIG_DIRECTORIES, base: "config")

    app_directories = Rails.root.join("app").children
      .select(&:directory?)
      .reject { |path| path.basename.to_s == "content" }
      .map { |path| path.basename.to_s }
    link_paths(temporary_root.join("app"), app_directories, base: "app")
  end

  def link_paths(destination_root, relative_paths, base: nil)
    relative_paths.each do |relative_path|
      source_path = Rails.root.join(*[base, relative_path].compact)
      FileUtils.ln_s(source_path, destination_root.join(relative_path))
    end
  end

  def write_invalid_resource(temporary_root, topic:, metadata:)
    source_path = temporary_root.join(
      "app/content/pages/writing/posts/2000-01-01-boot-invalid-#{SecureRandom.hex(8)}.markerb"
    )

    File.write(source_path, <<~CONTENT)
      ---
      title: Invalid boot resource
      #{topic_metadata(topic)}#{metadata}
      ---
      Invalid boot resource
    CONTENT

    source_path
  end

  def topic_metadata(topic)
    return "topic: #{topic}\n" unless topic.is_a?(Array)

    "topic:\n#{topic.map { |label| "  - #{label}\n" }.join}"
  end

  def run_boot(temporary_root, runner_sentinel)
    Open3.capture3(
      {
        "DISABLE_SPRING" => "1",
        "PARALLEL_WORKERS" => "1",
        "RAILS_ENV" => "test"
      },
      RbConfig.ruby,
      temporary_root.join("bin/rails").to_s,
      "runner",
      %(puts #{runner_sentinel.inspect}),
      chdir: temporary_root.to_s
    )
  end
end
