# frozen_string_literal: true

class PhlexMarkdownComponent < Phlex::Markdown
  def initialize(page)
    @page = page
    super(page.body)
  end

  def template
   
      super
   
  end

  def ul
    super(class: "bullet")
  end
end
