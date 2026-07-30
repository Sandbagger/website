# frozen_string_literal: true

class NavComponent < ApplicationComponent
  include PageHelper

  def view_template
    header(class: "site-header") do
      div(class: "center cluster-around") do
        link_to "William Neal", "/", class: "wordmark",
          aria: {label: "William Neal, home"}

        nav(aria_label: "Primary") do
          ul(class: "cluster", role: "list") do
            navigation_resources.each do |resource|
              li { link_to_page(resource) }
            end
          end
        end
      end
    end
  end

  private

  def navigation_resources
    [
      Sitepress.site.get("/"),
      Sitepress.site.get("/writing"),
      Sitepress.site.get("/about")
    ]
  end
end
