# frozen_string_literal: true

require "yaml"
require "digest/sha1"
require "fileutils"

# Simple deterministic SVG generator for post cover images.
class PostImageGenerator
  OUTPUT_DIR = "public/images/posts"
  WIDTH = 1200
  HEIGHT = 630

  def initialize(files, overwrite: false)
    @files = Array(files)
    @overwrite = overwrite
  end

  def generate_all
    FileUtils.mkdir_p(OUTPUT_DIR)
    @files.each do |file|
      metadata, _body = parse_frontmatter(file)
      slug = slug_for(file)
      title = metadata["title"] || slug.tr("_", " ").capitalize
      dest = File.join(OUTPUT_DIR, "#{slug}.svg")
      next if File.exist?(dest) && !@overwrite

      write_svg(slug, title, dest)
    end
  end

  private

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

    box_height = (text_lines.size * line_height) + (line_height * 0.8)
    box_y = start_y - (line_height * 0.6)

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
    path = Pathname(file)
    while (ext = path.extname) && !ext.empty?
      path = path.sub_ext("")
      break if ext == ".html" # stop after stripping .html
    end
    path.basename.to_s
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
