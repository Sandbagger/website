# frozen_string_literal: true

class ApplicationLayout < ApplicationView
  include Phlex::Rails::Layout
  include Phlex::Rails::Helpers::ContentFor
  include PageHelper

  def initialize
    @partials = []
    @cover_image = nil
    @page_title = nil
  end

  def view_template
    doctype

    html(lang: "en") do
      head do
        title { "William Neal" }
        meta name: "viewport", content: "width=device-width,initial-scale=1"
        meta name: "referrer", content: "strict-origin-when-cross-origin"
        csp_meta_tag
        csrf_meta_tags
        stylesheet_link_tag "application", data_turbo_track: "reload"
        javascript_include_tag "application", data_turbo_track: "reload", defer: true
        link(
          rel: "apple-touch-icon",
          sizes: "180x180",
          href: "/apple-touch-icon.png"
        )
        link(
          rel: "icon",
          type: "image/png",
          sizes: "16x16",
          href: "/favicon-16x16.png"
        )
        link(rel: "manifest", href: "/site.webmanifest")
        link(rel: "mask-icon", href: "/safari-pinned-tab.svg", color: "#61b9d2")
        link(rel: "alternate", type: "application/rss+xml", title: "William Neal's RSS feed", href: "https://williamneal.dev/feed")
      end

      body do
        render NavComponent.new

        main(class: "site-main") do
          div(class: "page-content center flow") do
            if @cover_image
              img(src: @cover_image[:src], alt: @cover_image[:alt], class: "cover")
            end
            h1 { @page_title } if @page_title

            raw @markdown if @markdown
            render_partials
          end
        end

        render FooterComponent.new
      end
    end
  end

  def cover_image(src, alt: nil)
    @cover_image = {src:, alt:}
  end

  # standard:disable Style/TrivialAccessors
  def markdown(md)
    @markdown = md
  end

  def page_title(title)
    @page_title = title
  end
  # standard:enable Style/TrivialAccessors

  def partial(component)
    @partials ||= []
    @partials << component
  end

  private

  def render_partials
    @partials.each { |partial| render partial }
  end
end
