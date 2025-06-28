# Restart the server to see changes made to this file.

class ApplicationMarkdown < MarkdownRails::Renderer::Rails
  # Reformats your boring punctation like " and " into “ and ” so you can look
  # and feel smarter. Read the docs at https://github.com/vmg/redcarpet#also-now-our-pants-are-much-smarter
  include Redcarpet::Render::SmartyPants

  # Run `bundle add rouge` and uncomment the include below for syntax highlighting
  # include MarkdownRails::Helper::Rouge

  # If you need access to ActionController::Base.helpers, you can delegate by uncommenting
  # and adding to the list below. Several are already included for you in the `MarkdownRails::Renderer::Rails`,
  # but you can add more here.
  #
  # To see a list of methods available run `bin/rails runner "puts ActionController::Base.helpers.public_methods.sort"`
  #
  # delegate \
  #   :request,
  #   :cache,
  #   :turbo_frame_tag,
  # to: :helpers

  # These flags control features in the Redcarpet renderer, which you can read
  # about at https://github.com/vmg/redcarpet#and-its-like-really-simple-to-use
  # Make sure you know what you're doing if you're using this to render user inputs.
  def enable
    [:fenced_code_blocks]
  end

  # Example of how you might override the images to show embeds, like a YouTube video.
  def image(link, title, alt)
    url = URI(link)
    case url.host
    when "www.youtube.com"
      youtube_tag url, alt
    else
      super
    end
  end

  private

  # This is provided as an example; there's many more YouTube URLs that this wouldn't catch.
  def youtube_tag(url, alt)
    embed_url = "https://www.youtube-nocookie.com/embed/#{CGI.parse(url.query).fetch("v").first}"
    content_tag :iframe,
      src: embed_url,
      width: 560,
      height: 325,
      allow: "encrypted-media; picture-in-picture",
      allowfullscreen: true \
        do alt end
  end
end


# Setup markdown stacks to work with different template handler in Rails.
MarkdownRails.handle :md, :markdown do
  ApplicationMarkdown.new
end

# Don't use Erb for untrusted markdown content created by users; otherwise they
# can execute arbitrary code on your server. This should only be used for input you
# trust, like content files from your code repo.
class ErbMarkdown < ApplicationMarkdown
  # Enables Erb to render for the entire doc before the markdown is rendered.
  # This works great, except when you have an `erb` code fence.
  def preprocess(html)
    # Read more about this render call at https://guides.rubyonrails.org/layouts_and_rendering.html
    render inline: html, handler: :erb
  end
end

# Don't use Erb for untrusted markdown content created by users; otherwise they
# can execute arbitrary code on your server. This should only be used for input you
# trust, like content files from your code repo.
MarkdownRails.handle :markerb do
  ErbMarkdown.new
end
