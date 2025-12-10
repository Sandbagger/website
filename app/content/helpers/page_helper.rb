module PageHelper
  extend Phlex::Rails::HelperMacros
  register_value_helper :current_page
  # Creates a hyperlink to a page using the `title` key. Change the default in the args
  # below if you use a different key for page titles.
  def link_to_page(page, title_key: 'title')
    if page == current_page
      link_to page.data.fetch(title_key, page.request_path), page.request_path, class: 'active'
    else
      link_to page.data.fetch(title_key, page.request_path), page.request_path
    end
  end

  # Quick and easy way to change the class of a page if its current. Useful for
  # navigation menus.
  def link_to_if_current(text, page, active_class: 'active')
    if page == current_page
      link_to text, page.request_path, class: active_class
    else
      link_to text, page.request_path
    end
  end

  # Conditionally renders the block if an arg is present. If all the args are nil,
  # the block is not rendered. Handy for laconic templating languages like slim, haml, etc.
  def with(*args, &block)
    block.call(*args) unless args.all?(&:nil?)
  end

  # Render a block within a layout. This is a useful, and prefered way, to handle
  # nesting layouts, within Sitepress.
  def render_layout(layout, **, &)
    render(html: capture(&), layout: "layouts/#{layout}", **)
  end

  # def writings
  #   Sitepress.site.resources.glob("writing/*").select do |resource|
  #     next if resource.data["publish_at"].nil?
  #     resource.data["publish_at"] <= Date.today
  #   end.compact.sort_by { |resource| resource.data["publish_at"] }.reverse
  # end
end
