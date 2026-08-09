# frozen_string_literal: true

require "test_helper"
require "base64"
require "fastimage"
require "fileutils"
require "tmpdir"

class Writing::CoverTest < ActiveSupport::TestCase
  Resource = Data.define(:request_path)

  SIZES = {
    480 => 252,
    768 => 403,
    1200 => 630
  }.freeze
  CANONICAL_SLUG = "pettis-good-tariffs-vs-bad"
  LOSSY_WEBP = "UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAUAmJaQAA3AA/vz0AAA="
  INVALID_VARIANTS_MESSAGE =
    "Invalid responsive cover variants: expected ordered dimensions #{SIZES.to_a.inspect}"
  INVALID_DIMENSION_SETS = {
    "empty" => [],
    "partial" => [[480, 252], [768, 403]],
    "unordered" => [[768, 403], [480, 252], [1200, 630]],
    "duplicate" => [[480, 252], [768, 403], [768, 403]],
    "wrong-dimension" => [[480, 252], [768, 404], [1200, 630]]
  }.freeze

  test "find returns immutable responsive metadata for a canonical cover" do
    cover = Writing::Cover.find(resource(CANONICAL_SLUG))
    original_hash = cover.hash

    assert_instance_of Writing::Cover, cover
    assert_equal [480, 768, 1200], cover.variants.map(&:width)
    assert_equal [252, 403, 630], cover.variants.map(&:height)
    assert_equal "/images/posts/#{CANONICAL_SLUG}-1200w.webp", cover.src
    assert_equal [
      "/images/posts/#{CANONICAL_SLUG}-480w.webp 480w",
      "/images/posts/#{CANONICAL_SLUG}-768w.webp 768w",
      "/images/posts/#{CANONICAL_SLUG}-1200w.webp 1200w"
    ].join(", "), cover.srcset
    assert_equal 1200, cover.width
    assert_equal 630, cover.height
    assert_predicate cover, :frozen?
    assert_predicate cover.variants, :frozen?
    cover.variants.each do |variant|
      assert_predicate variant, :frozen?
      assert_predicate variant.src, :frozen?
    end
    assert_raises(FrozenError) { cover.variants << cover.variants.first }
    assert_raises(FrozenError) { cover.variants.first.src << "-mutated" }
    assert_equal original_hash, cover.hash
  end

  test "initialization does not freeze the caller's variant array or source strings" do
    sources = SIZES.map { |width, _height| +"/images/posts/example-#{width}w.webp" }
    variants = SIZES.map.with_index do |(width, height), index|
      Writing::Cover::Variant.new(src: sources.fetch(index), width: width, height: height)
    end

    cover = Writing::Cover.new(variants: variants)

    refute_same variants, cover.variants
    assert_equal SIZES.to_a, cover.variants.map { [_1.width, _1.height] }
    refute_predicate variants, :frozen?
    sources.each { refute_predicate _1, :frozen? }
  end

  test "from_props applies the immutable cover seals" do
    sources = SIZES.map { |width, _height| +"/images/posts/example-#{width}w.webp" }
    variants = SIZES.map.with_index do |(width, height), index|
      Writing::Cover::Variant.from_props(
        src: sources.fetch(index),
        width: width,
        height: height
      )
    end
    first_variant = variants.first
    cover = Writing::Cover.from_props(variants: variants)

    sources.first << "-mutated"
    variants << first_variant

    assert_equal "/images/posts/example-480w.webp", first_variant.src
    assert_predicate first_variant.src, :frozen?
    assert_equal SIZES.to_a, cover.variants.map { [_1.width, _1.height] }
    assert_predicate cover.variants, :frozen?
    refute_same variants, cover.variants
  end

  INVALID_DIMENSION_SETS.each do |description, dimensions|
    test "initialization rejects #{description} responsive variants" do
      error = assert_raises(Writing::Cover::Invalid) do
        Writing::Cover.new(variants: variants_for(dimensions))
      end

      assert_equal INVALID_VARIANTS_MESSAGE, error.message
    end
  end

  test "find returns nil when all responsive candidates are absent" do
    assert_nil Writing::Cover.find(resource("does-not-have-a-cover"))
  end

  SIZES.each_key do |missing_width|
    test "find rejects a responsive set missing #{missing_width}w" do
      with_cover_root do |root|
        copy_variants(root, slug: "partial", except: [missing_width])
        path = root.join("partial-#{missing_width}w.webp")

        error = assert_raises(Writing::Cover::Invalid) do
          Writing::Cover.find(resource("partial"), root: root)
        end
        assert_equal "Invalid WebP cover variant: #{path}", error.message
      end
    end
  end

  test "find rejects non-WebP content with a variant suffix" do
    with_cover_root do |root|
      copy_variants(root, slug: "wrong-format")
      path = root.join("wrong-format-480w.webp")
      path.binwrite(Base64.strict_decode64(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
      ))

      assert_invalid_variant("wrong-format", path, root)
    end
  end

  test "find rejects a lossy WebP variant" do
    with_cover_root do |root|
      copy_variants(root, slug: "lossy")
      path = root.join("lossy-480w.webp")
      path.binwrite(Base64.strict_decode64(LOSSY_WEBP))

      assert_equal :webp, FastImage.type(path.to_s)
      assert_equal "VP8 ", path.binread(4, 12)
      assert_invalid_variant("lossy", path, root)
    end
  end

  test "find rejects a lossless WebP variant with unreadable dimensions" do
    with_cover_root do |root|
      copy_variants(root, slug: "corrupt")
      path = root.join("corrupt-480w.webp")
      path.binwrite("RIFF" + [8].pack("V") + "WEBP" + "VP8L")

      assert_equal :webp, FastImage.type(path.to_s)
      assert_equal "VP8L", path.binread(4, 12)
      assert_nil FastImage.size(path.to_s)
      assert_invalid_variant("corrupt", path, root)
    end
  end

  test "find rejects a variant whose dimensions do not match its suffix" do
    with_cover_root do |root|
      copy_variants(root, slug: "wrong-size")
      path = root.join("wrong-size-768w.webp")
      FileUtils.cp(canonical_variant(480), path)

      assert_equal [480, 252], FastImage.size(path.to_s)
      assert_invalid_variant("wrong-size", path, root)
    end
  end

  test "find rejects an unreadable variant with the path-specific error" do
    with_cover_root do |root|
      copy_variants(root, slug: "unreadable")
      path = root.join("unreadable-480w.webp")
      FileUtils.chmod(0o000, path)

      begin
        assert_raises(Errno::EACCES) { path.binread(1) }
        error = begin
          Writing::Cover.find(resource("unreadable"), root: root)
        rescue => raised
          raised
        end

        assert_instance_of Writing::Cover::Invalid, error
        assert_equal "Invalid WebP cover variant: #{path}", error.message
      ensure
        FileUtils.chmod(0o600, path)
      end
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

  def copy_variants(root, slug:, except: [])
    SIZES.each_key do |width|
      next if except.include?(width)

      FileUtils.cp(canonical_variant(width), root.join("#{slug}-#{width}w.webp"))
    end
  end

  def canonical_variant(width)
    Rails.root.join("public/images/posts/#{CANONICAL_SLUG}-#{width}w.webp")
  end

  def variants_for(dimensions)
    dimensions.map.with_index do |(width, height), index|
      Writing::Cover::Variant.new(
        src: +"/images/posts/example-#{index}.webp",
        width: width,
        height: height
      )
    end
  end

  def assert_invalid_variant(slug, path, root)
    error = assert_raises(Writing::Cover::Invalid) do
      Writing::Cover.find(resource(slug), root: root)
    end
    assert_equal "Invalid WebP cover variant: #{path}", error.message
  end
end
