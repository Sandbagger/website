module Sitepress
  class SiteController < ::ApplicationController
    include Sitepress::SitePages
    layout false

    protected

    # default if no layout is specified in frontmatter
     def default_layout(page)
      ApplicationLayout.new do | l |
        l.markdown render_resource_inline(page)
      end
    end
    

    def writing_layout(page)
     ApplicationLayout.new do | l |
        l.markdown render_resource_inline(page)
        l.partial CollectionComponent.new(published)
      end
    end

    private

    def render_resource_with_handler(resource)
      render layout_component(resource)
    end

    def render_resource_inline(resource)
      render inline: resource.body, type: resource.handler
    end

    # parses frontmatter for layout 
    def layout_component(resource)
      Rails.logger.debug resource
      Rails.logger.debug resource.data

      method_name = resource.data.fetch("layout", "default").concat("_layout")
      Rails.logger.debug method_name
      layout_method = method(method_name)
      begin
        layout_method.call(resource)
      rescue NameError
        writing_layout(resource)
      end
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
