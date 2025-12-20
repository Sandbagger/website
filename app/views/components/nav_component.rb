# frozen_string_literal: true

class NavComponent < ApplicationComponent
  include PageHelper

  def view_template
    nav do
      ul(class: 'cluster') do
        h3 { 'William Neal' }

        ul(class: 'cluster', role: 'list') do
          li do
            link_to_page(Sitepress.site.get('/'))
          end

          li do
            link_to_page(Sitepress.site.get('/about'))
          end

          li do
            link_to 'Toots', 'https://ruby.social/@Sandbagger', target: '_blank', rel: 'noopener noreferrer me'
          end

          li do
            link_to 'Skeets', 'https://bsky.app/profile/williamneal.bsky.social', target: '_blank',
                                                                                  rel: 'noopener noreferrer me'
          end
        end
      end
    end
  end
end
