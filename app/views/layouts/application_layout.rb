# frozen_string_literal: true

class ApplicationLayout < ApplicationView
  include Phlex::Rails::Layout
  include Phlex::Rails::Helpers::ContentFor
  include PageHelper

  def template(&block)
    doctype

    html do
      head do
        title { "You're awesome" }
        meta name: "viewport", content: "width=device-width,initial-scale=1"
        csp_meta_tag
        csrf_meta_tags
        stylesheet_link_tag "application", data_turbo_track: "reload"
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
      end

      nav do
        cluster do
          Sitepress.site.resources.each do |resource|
            break if resource.request_path.count('/') > 1
            li do
              link_to_page(resource)            
            end
          end
        end
      end

      body(class: "center") do
        main(class: "stack", &block)
      end
    end
  end

  def partial(&)
    section(&)
  end
end