# frozen_string_literal: true

require "fastimage"

module Writing
  class Cover < Literal::Data
    class Invalid < StandardError; end

    class Variant < Literal::Data
      prop :src, String
      prop :width, Integer
      prop :height, Integer

      private

      def after_initialize
        @src = src.dup.freeze
      end
    end

    SIZES = {
      480 => 252,
      768 => 403,
      1200 => 630
    }.freeze

    prop :variants, _Array(Variant)

    def self.find(resource, root: Rails.root.join("public/images/posts"))
      slug = Pathname(resource.request_path.to_s).basename.to_s
      paths = SIZES.to_h do |width, height|
        [Pathname(root).join("#{slug}-#{width}w.webp"), [width, height]]
      end
      return unless paths.keys.any?(&:file?)

      variants = paths.map do |path, dimensions|
        invalid!(path) unless valid?(path, dimensions)

        Variant.new(
          src: "/images/posts/#{path.basename}",
          width: dimensions.first,
          height: dimensions.last
        )
      end
      new(variants: variants)
    end

    def self.valid?(path, dimensions)
      return false unless path.file?
      return false unless FastImage.type(path.to_s) == :webp
      return false unless path.binread(4, 12) == "VP8L"

      image = Sitepress::Image.new(path: path)
      dimensions == [image.width, image.height]
    rescue Errno::EACCES, Errno::ENOENT
      false
    end
    private_class_method :valid?

    def self.invalid!(path)
      raise Invalid, "Invalid WebP cover variant: #{path}"
    end
    private_class_method :invalid!

    def src = fallback.src

    def srcset
      variants.map { |variant| "#{variant.src} #{variant.width}w" }.join(", ")
    end

    def width = fallback.width

    def height = fallback.height

    private

    def fallback = variants.last

    def after_initialize
      @variants = variants.dup.freeze
      return if variants.map { [_1.width, _1.height] } == SIZES.to_a

      raise Invalid,
        "Invalid responsive cover variants: expected ordered dimensions #{SIZES.to_a.inspect}"
    end
  end
end
