# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "rake"
require Rails.root.join("lib/post_image_generator")

Rails.application.load_tasks unless Rake::Task.task_defined?("images:generate_posts")

class PostImageGeneratorTest < ActiveSupport::TestCase
  test "dated post generates a cover with its canonical slug" do
    in_temporary_site do
      post = write_page(
        "app/content/pages/writing/posts/2024-03-10-example.markerb",
        title: "Example"
      )

      PostImageGenerator.new(post).generate_all

      assert_path_exists "public/images/posts/example.svg"
      refute_path_exists "public/images/posts/2024-03-10-example.svg"
    end
  end

  test "extensionless draft generates a cover with its draft slug" do
    in_temporary_site do
      draft = write_page(
        "app/content/pages/writing/drafts/example",
        title: "Example"
      )

      PostImageGenerator.new(draft).generate_all

      assert_path_exists "public/images/posts/example.svg"
    end
  end

  test "generation is deterministic and skips existing covers unless overwriting" do
    in_temporary_site do
      draft = write_page(
        "app/content/pages/writing/drafts/example.markerb",
        title: "Example"
      )
      cover = "public/images/posts/example.svg"

      PostImageGenerator.new(draft).generate_all
      generated_svg = File.read(cover)
      File.write(cover, "existing cover")

      PostImageGenerator.new(draft).generate_all
      assert_equal "existing cover", File.read(cover)

      PostImageGenerator.new(draft, overwrite: true).generate_all
      assert_equal generated_svg, File.read(cover)
    end
  end

  test "duplicate canonical slugs fail before creating a cover" do
    in_temporary_site do
      draft = write_page(
        "app/content/pages/writing/drafts/example.markerb",
        title: "Draft"
      )
      post = write_page(
        "app/content/pages/writing/posts/2024-03-10-example.markerb",
        title: "Post"
      )

      error = assert_raises(PostImageGenerator::SlugCollision) do
        PostImageGenerator.new([draft, post]).generate_all
      end

      assert_includes error.message, "example"
      assert_includes error.message, draft
      assert_includes error.message, post
      refute_path_exists "public/images/posts/example.svg"
    end
  end

  test "duplicate canonical slugs fail before overwriting an existing cover" do
    in_temporary_site do
      draft = write_page(
        "app/content/pages/writing/drafts/example.markerb",
        title: "Draft"
      )
      post = write_page(
        "app/content/pages/writing/posts/2024-03-10-example.markerb",
        title: "Post"
      )
      cover = "public/images/posts/example.svg"
      FileUtils.mkdir_p(File.dirname(cover))
      File.write(cover, "existing cover")

      assert_raises(PostImageGenerator::SlugCollision) do
        PostImageGenerator.new([draft, post], overwrite: true).generate_all
      end

      assert_equal "existing cover", File.read(cover)
    end
  end

  test "rake task generates covers only for direct drafts and posts" do
    in_temporary_site do
      write_page("app/content/pages/writing/drafts/draft", title: "Draft")
      write_page(
        "app/content/pages/writing/posts/2024-03-10-post.markerb",
        title: "Post"
      )
      write_page("app/content/pages/writing/template.markerb", title: "Template")
      write_page(
        "app/content/pages/writing/posts/nested/2024-03-10-nested.markerb",
        title: "Nested"
      )

      capture_io { Rake::Task["images:generate_posts"].invoke }

      assert_path_exists "public/images/posts/draft.svg"
      assert_path_exists "public/images/posts/post.svg"
      refute_path_exists "public/images/posts/template.svg"
      refute_path_exists "public/images/posts/nested.svg"
    ensure
      Rake::Task["images:generate_posts"].reenable
    end
  end

  private

  def in_temporary_site(&block)
    Dir.mktmpdir("post-image-generator") do |directory|
      Dir.chdir(directory, &block)
    end
  end

  def write_page(path, title:)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "---\ntitle: #{title}\n---\n")
    path
  end
end
