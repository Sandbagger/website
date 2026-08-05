module Sitepress
  class SiteController < ::ApplicationController
    include Sitepress::SitePages
    include PostCoverHelper
    layout false

    class_attribute :writing_publication_clock,
      instance_writer: false,
      default: Writing::PublicationClock.new
    class_attribute :writing_publication_environment,
      instance_writer: false,
      default: Rails.env

    protected

    def render_resource(resource)
      path = writing_path(resource)
      if path&.post? && !publication_policy.accessible?(path)
        raise Sitepress::ResourceNotFound, "No such page: #{resource.request_path}"
      end

      super
    end

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
      writing_path(page).present?
    end

    def published
      catalogue.published(exclude: request.path)
    end

    def catalogue
      Writing::Catalogue.new(
        resources: Sitepress.site.resources,
        policy: publication_policy
      )
    end

    def publication_policy
      Writing::PublicationPolicy.new(
        environment: writing_publication_environment,
        clock: writing_publication_clock
      )
    end

    def writing_path(resource)
      Writing::Path.new(resource.source.path)
    rescue Writing::Path::Invalid
      nil
    end
  end
end
