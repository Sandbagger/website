# frozen_string_literal: true

class NavComponent < ApplicationComponent
  include PageHelper
  
  def template
    nav do
      cluster do
        Sitepress.site.resources.glob("*.html.*").each do |resource|
          li do
            link_to_page(resource)            
          end
        end
        li do
          link_to "Mastodon", "https://ruby.social/@Sandbagger", target: "_blank", rel: "noopener noreferrer me"
        end
      end
    end
  end
end
