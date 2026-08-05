# frozen_string_literal: true

require "fastimage"

module Writing
  class Cover < Literal::Data
    class Invalid < StandardError; end

    prop :src, String
    prop :width, Integer
    prop :height, Integer

    def self.find(resource, root: Rails.root.join("public/images/posts"))
      slug = Pathname(resource.request_path.to_s).basename.to_s
      path = Pathname(root).join("#{slug}.webp")
      return unless path.file?

      invalid!(path) unless FastImage.type(path.to_s) == :webp

      image = Sitepress::Image.new(path: path)
      invalid!(path) unless image.width&.positive? && image.height&.positive?

      new(
        src: "/images/posts/#{slug}.webp",
        width: image.width,
        height: image.height
      )
    end

    def self.invalid!(path)
      raise Invalid, "Invalid WebP cover: #{path}"
    end
    private_class_method :invalid!

    private

    def after_initialize
      @src = src.dup.freeze
    end
  end
end
