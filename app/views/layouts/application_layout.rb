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
      end

      body(class: "center") do
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
        main(class: "stack", &block)
      end
    end
  end
end