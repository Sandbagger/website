# frozen_string_literal: true

class ApplicationLayout < ApplicationView
  include Phlex::Rails::Layout
  include Phlex::Rails::Helpers::ContentFor
  include PageHelper

  def template(&block)
    doctype

    html do
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
        style { ".hit:hover { border-image: var(--path);  }" }
      end

      render NavComponent.new

      # disabling data-controller="hit" for now as referrer is not working and the css only option  
      # works the in the same way
      body(class: "center") do
        main(class: "flow", &block)
      end
    end
  end

  def partial(&)
    section(class: "flow", &)
  end
end
