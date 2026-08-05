# frozen_string_literal: true

require "test_helper"
require "base64"
require "fastimage"
require "tmpdir"

class Writing::CoverTest < ActiveSupport::TestCase
  Resource = Data.define(:request_path)

  test "find returns immutable metadata for a canonical WebP cover" do
    cover = Writing::Cover.find(resource("pettis-good-tariffs-vs-bad"))
    original_hash = cover.hash

    assert_instance_of Writing::Cover, cover
    assert_equal "/images/posts/pettis-good-tariffs-vs-bad.webp", cover.src
    assert_equal 1200, cover.width
    assert_equal 630, cover.height
    assert_predicate cover, :frozen?
    assert_predicate cover.src, :frozen?
    assert_raises(FrozenError) { cover.src << "-mutated" }
    assert_equal original_hash, cover.hash
  end

  test "initialization does not freeze the caller's source string" do
    src = +"/images/posts/example.webp"

    cover = Writing::Cover.new(src: src, width: 1200, height: 630)

    refute_same src, cover.src
    refute_predicate src, :frozen?
    assert_equal "/images/posts/example.webp", src
  end

  test "find returns nil when the canonical WebP cover is absent" do
    assert_nil Writing::Cover.find(resource("does-not-have-a-cover"))
  end

  test "find rejects non-WebP content with a WebP suffix" do
    with_cover_root do |root|
      path = root.join("wrong-format.webp")
      path.binwrite(Base64.strict_decode64(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
      ))

      assert_equal :png, FastImage.type(path.to_s)

      error = assert_raises(Writing::Cover::Invalid) do
        Writing::Cover.find(resource("wrong-format"), root: root)
      end
      assert_equal "Invalid WebP cover: #{path}", error.message
    end
  end

  test "find rejects WebP content with unreadable dimensions" do
    with_cover_root do |root|
      path = root.join("corrupt.webp")
      path.binwrite("RIFF" + [4].pack("V") + "WEBP")

      assert_equal :webp, FastImage.type(path.to_s)
      assert_nil FastImage.size(path.to_s)

      error = assert_raises(Writing::Cover::Invalid) do
        Writing::Cover.find(resource("corrupt"), root: root)
      end
      assert_equal "Invalid WebP cover: #{path}", error.message
    end
  end

  private

  def resource(slug)
    Resource.new("/writing/#{slug}")
  end

  def with_cover_root
    Dir.mktmpdir("writing-cover") do |directory|
      yield Pathname(directory)
    end
  end
end
