module Sitepress
  class SiteController < ::ApplicationController
    include Sitepress::SitePages
    layout false

    protected

    # default if no layout is specified in frontmatter
     def default_layout(page)
      Rails.logger.info "Page request: #{request.query_parameters.inspect}, User Agent: #{request.user_agent}, Referer: #{request.referer}"
      # Rails does not let you pass stuff to layouts
      ApplicationLayout.new do |layout|
        layout.partial do
          render_resource_inline page
        end
      end
    end
    
    def page_layout(page)
      Rails.logger.info "Page request: #{request.query_parameters.inspect}, User Agent: #{request.user_agent}, Referer: #{request.referer}"
      # Rails does not let you pass stuff to layouts
      ApplicationLayout.new do |layout|
        layout.partial do
          PhlexMarkdownComponent.new(page).call.html_safe
        end

        layout.partial do
          render CollectionComponent.new(
            site.resources.glob("writing/*").select do |resource|
              next if resource.data["publish_at"].nil?
              next if resource == page
              resource.data["publish_at"] <= Date.today
            end.compact.sort_by { |resource| resource.data["publish_at"] }.reverse
          )
        end
      end
    end

    def application_layout(page)
      ApplicationLayout.new do
        PhlexMarkdownComponent.new(page).call.html_safe
      end
    end

    def writing_layout(page)
      ApplicationLayout.new do |layout|
        layout.partial do
          PhlexMarkdownComponent.new(page).call.html_safe
        end
      end
    end

    private

    def render_resource_with_handler(resource)
      render layout_component(resource)
    end

    def render_resource_inline(resource)
      render inline: resource.body, type: resource.handler
    end

    def layout_component(resource)
      method_name = resource.data.fetch("layout", "default").concat("_layout")
      layout_method = method(method_name)
      layout_method.call resource
    end
  end
end
