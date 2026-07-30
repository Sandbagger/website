module Sitepress
  class SiteController < ::ApplicationController
    include Sitepress::SitePages
    include PostCoverHelper
    layout false

    protected

    # default if no layout is specified in frontmatter
    def default_layout(page)
      article = writing_post?(page)

      ApplicationLayout.new.tap do |layout|
        layout.page_kind(article ? :article : :default)
        layout.page_title(page_title_for(page))
        if article
          layout.page_metadata(
            topic: page.data["topic"],
            publish_at: page.data["publish_at"]
          )
        end
        attach_cover(layout, page)
        layout.markdown(render_resource_inline(page))
        if article
          layout.partial(
            CollectionComponent.new(published, context: :article)
          )
        end
      end
    end

    def home_layout(page)
      ApplicationLayout.new.tap do |layout|
        layout.page_kind(:home)
        layout.markdown(render_resource_inline(page))
        layout.partial(
          CollectionComponent.new(published, context: :home)
        )
      end
    end

    def writing_layout(page)
      ApplicationLayout.new.tap do |layout|
        layout.page_kind(:archive)
        layout.page_title(page_title_for(page))
        layout.markdown(render_resource_inline(page))
        layout.partial(
          CollectionComponent.new(published, context: :archive)
        )
      end
    end

    private

    def render_resource_with_handler(resource)
      render layout_component(resource)
    end

    def render_resource_inline(resource)
      render_to_string inline: resource.body, type: resource.handler
    end

    def page_title_for(page)
      page.data["title"].presence ||
        page.try(:title).presence ||
        page.request_path.titleize
    end

    def attach_cover(layout, page)
      src = post_cover_path(page)
      layout.cover_image(src, alt: "") if src
    end

    # parses frontmatter for layout
    def layout_component(resource)
      Rails.logger.info resource
      Rails.logger.info resource.data

      method_name = resource.data.fetch("layout", "default") + "_layout"
      Rails.logger.info method_name
      layout_method = method(method_name)
      layout_method.call(resource)
    end

    def writing_post?(page)
      page.request_path.to_s.match?(%r{\A/?writing/})
    end

    def published(exclude: nil)
      Sitepress.site.resources.glob("writing/*").select do |res|
        next if res.request_path == request.path # Exclude current page
        next if res.data["publish_at"].nil?
        res.data["publish_at"] <= Date.today
      end.sort_by { |res| res.data["publish_at"] }.reverse
    end
  end
end
