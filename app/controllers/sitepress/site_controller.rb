module Sitepress
  class SiteController < ::ApplicationController
    include Sitepress::SitePages
    layout false

    protected

    # default if no layout is specified in frontmatter
    def default_layout(page)
      title = page.data["title"].presence || page.try(:title).presence || page.request_path.titleize
      ApplicationLayout.new.tap do |layout|
        attach_cover(layout, page)
        layout.page_title(title)
        layout.markdown(render_resource_inline(page))
      end
    end

    def writing_layout(page)
      title = page.data["title"].presence || page.try(:title).presence || page.request_path.titleize
      ApplicationLayout.new.tap do |layout|
        attach_cover(layout, page)
        layout.page_title(title)
        layout.markdown(render_resource_inline(page))
        layout.partial(CollectionComponent.new(published))
      end
    end

    private

    def render_resource_with_handler(resource)
      render layout_component(resource)
    end

    def render_resource_inline(resource)
      render_to_string inline: resource.body, type: resource.handler
    end

    def cover_slug_for(page)
      path = page.try(:logical_path) || page.request_path
      pn = Pathname(path)
      # Strip multiple extensions like .html.markerb
      while (ext = pn.extname) && !ext.empty?
        pn = pn.sub_ext("")
      end
      pn.basename.to_s
    end

    def attach_cover(layout, page)
      slug = cover_slug_for(page)
      cover = Rails.root.join("public/images/posts/#{slug}.svg")
      return unless File.exist?(cover)

      layout.cover_image("/images/posts/#{slug}.svg", alt: page.data["title"])
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

    def published(exclude: nil)
      Sitepress.site.resources.glob("writing/*").select do |res|
        next if res.request_path == request.path # Exclude current page
        next if res.data["publish_at"].nil?
        res.data["publish_at"] <= Date.today
      end.sort_by { |res| res.data["publish_at"] }.reverse
    end
  end
end
