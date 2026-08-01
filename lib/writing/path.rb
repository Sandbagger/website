# frozen_string_literal: true

require "date"

module Writing
  class Path
    class Invalid < StandardError; end

    attr_reader :source_path, :slug, :publication_date

    def initialize(source_path)
      @source_path = source_path.to_s
      kind, filename = classify!
      stem = strip_handler_extension!(filename)

      if kind == "posts"
        @publication_date, @slug = parse_post_stem!(stem)
      else
        @slug = parse_draft_stem!(stem)
      end

      @post = kind == "posts"
    end

    def post? = @post

    def draft? = !post?

    def request_path
      return "/writing/#{slug}" if post?

      preview_path
    end

    def preview_path
      return unless draft?

      "/writing/drafts/#{slug}"
    end

    private

    def classify!
      match = source_path.match(%r{(?:\A|/)writing/(posts|drafts)/([^/]+)\z})
      fail_invalid!("must be directly under writing/posts or writing/drafts") unless match

      match.captures
    end

    def strip_handler_extension!(filename)
      match = filename.match(/\A(.+?)(?:\.html)?\.(?:markerb|md)\z/)
      fail_invalid!("has an unsupported handler extension") unless match

      match[1]
    end

    def parse_post_stem!(stem)
      match = stem.match(/\A(\d{4}-\d{2}-\d{2})-(.*)\z/)
      fail_invalid!("is missing a publication date") unless match

      date = Date.iso8601(match[1])
      slug = match[2]
      fail_invalid!("is missing a slug") if slug.empty?

      [date, slug]
    rescue Date::Error
      fail_invalid!("has an invalid publication date")
    end

    def parse_draft_stem!(stem)
      fail_invalid!("is missing a slug") if stem.empty?

      stem
    end

    def fail_invalid!(reason)
      fail Invalid, "Invalid writing path #{source_path.inspect}: #{reason}"
    end
  end
end
