# frozen_string_literal: true

require "yaml"
require "digest/sha1"
require "fileutils"
require_relative "writing/path"

# Simple deterministic SVG generator for post cover images.
class PostImageGenerator
  class SlugCollision < StandardError; end

  OUTPUT_DIR = "public/images/posts"
  WIDTH = 1200
  HEIGHT = 630

  def initialize(files, overwrite: false)
    @files = Array(files)
    @overwrite = overwrite
  end

  def generate_all
    paths = @files.map { |file| [file, slug_for(file)] }
    ensure_unique_slugs!(paths)

    FileUtils.mkdir_p(OUTPUT_DIR)
    paths.each do |file, slug|
      metadata, _body = parse_frontmatter(file)
      title = metadata["title"] || slug.tr("_", " ").capitalize
      dest = File.join(OUTPUT_DIR, "#{slug}.svg")
      next if File.exist?(dest) && !@overwrite

      write_svg(slug, title, dest)
    end
  end

  private

  def ensure_unique_slugs!(paths)
    source_by_slug = {}

    paths.each do |file, slug|
      if (existing = source_by_slug[slug])
        fail SlugCollision,
          "Duplicate cover slug #{slug.inspect} for #{existing.inspect} and #{file.inspect}"
      end

      source_by_slug[slug] = file
    end
  end

  def parse_frontmatter(path)
    content = File.read(path)
    return [{}, content] unless content.start_with?("---")

    _sep, yaml, *rest = content.split(/^---\s*$\n?/, 3)
    metadata = YAML.safe_load(
      yaml,
      permitted_classes: [Date, Time],
      aliases: false
    ) || {}
    [metadata, rest.join]
  rescue Psych::SyntaxError
    [{}, content]
  end

  def write_svg(slug, title, path)
    seed = Digest::SHA1.hexdigest(slug).hex
    rng = Random.new(seed)

    colors = palette(seed)
    circles = 6.times.map { circle(rng, colors.sample(random: rng)) }
    gradient = gradient_def(colors.first, colors.last)
    text_lines = wrap_title(title)
    line_height = 76
    start_y = (HEIGHT / 2) - ((text_lines.size - 1) * line_height / 2)

    text_svg = text_lines.each_with_index.map do |line, idx|
      y = start_y + (idx * line_height)
      %(<text x="#{WIDTH / 2}" y="#{y}" text-anchor="middle" font-family="Space Mono, monospace" font-weight="800" font-size="72" fill="#0b1021" stroke="#f8fafc" stroke-width="3" paint-order="stroke fill" opacity="1" letter-spacing="0.5">#{escape(line)}</text>)
    end.join("\n")

    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{WIDTH} #{HEIGHT}" role="img" aria-label="#{escape(title)}">
        #{gradient}
        <rect width="#{WIDTH}" height="#{HEIGHT}" fill="url(#bg)"/>
        #{circles.join("\n")}
        #{text_svg}
      </svg>
    SVG

    File.write(path, svg)
  end

  def slug_for(file)
    Writing::Path.new(file).slug
  end

  def wrap_title(text, width: 18)
    words = text.to_s.split(/\s+/)
    lines = []
    line = ""
    words.each do |word|
      if (line + " " + word).strip.length > width
        lines << line.strip
        line = word
      else
        line = [line, word].reject(&:empty?).join(" ")
      end
    end
    lines << line.strip unless line.empty?
    lines = [text] if lines.empty?
    lines.take(3) # cap lines to avoid overflow
  end

  def gradient_def(start_color, end_color)
    <<~GRADIENT
      <defs>
        <linearGradient id="bg" x1="0" x2="1" y1="0" y2="1">
          <stop offset="0%" stop-color="#{start_color}" stop-opacity="0.9"/>
          <stop offset="100%" stop-color="#{end_color}" stop-opacity="0.9"/>
        </linearGradient>
      </defs>
    GRADIENT
  end

  def circle(rng, color)
    cx = rng.rand(WIDTH * 0.1..WIDTH * 0.9).round(1)
    cy = rng.rand(HEIGHT * 0.2..HEIGHT * 0.8).round(1)
    r = rng.rand(60..180)
    opacity = rng.rand(0.08..0.18).round(2)
    %(<circle cx="#{cx}" cy="#{cy}" r="#{r}" fill="#{color}" opacity="#{opacity}"/>)
  end

  def palette(seed)
    hues = 3.times.map do |i|
      # spread hues based on seed and index for variety
      ((seed >> (i * 8)) & 255) % 360
    end
    hues.map { |h| "hsl(#{h}, 70%, 60%)" }
  end

  def escape(text)
    text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end
end
