# frozen_string_literal: true

class PhlexMarkdownComponent < Phlex::Markdown
  def initialize(page)
    @page = page
    super(page)
  end

  def view_template
    div(class: "flow") do
      super
    end
  end
end
