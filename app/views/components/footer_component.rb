# frozen_string_literal: true

class FooterComponent < ApplicationComponent
  def view_template
    footer(class: "site-footer") do
      div(class: "center cluster-around") do
        small { "Engineer, writer, enthusiastic generalist." }

        ul(class: "cluster", role: "list") do
          li { link_to "RSS", "/feed" }
          li { external_link("Mastodon", "https://ruby.social/@Sandbagger") }
          li { external_link("Bluesky", "https://bsky.app/profile/williamneal.bsky.social") }
        end
      end
    end
  end

  private

  def external_link(label, href)
    link_to label, href,
      target: "_blank",
      rel: "noopener noreferrer me"
  end
end
