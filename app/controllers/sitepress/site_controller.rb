module Sitepress
  class SiteController < ::ApplicationController
    include Sitepress::SitePages
    layout false

    protected

    def page_layout(page)
      # Rails does not let you pass stuff to layouts
      ApplicationLayout.new do |layout|
        layout.partial do
          PhlexMarkdownComponent.new(page).call.html_safe
        end

        layout.partial do
          render CollectionComponent.new(
            site.resources.glob("writing/*").select do |resource|
              next if resource.data["publish"].nil?
              next if resource == page
              resource.data["publish"] <= Date.today
            end.compact.sort_by { |resource| resource.data["publish"] }.reverse
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
      method_name = resource.data.fetch("layout", "page").concat("_layout")
      layout_method = method(method_name)
      layout_method.call resource
    end
  end
end
