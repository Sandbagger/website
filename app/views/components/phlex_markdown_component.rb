# frozen_string_literal: true

class PhlexMarkdownComponent < Phlex::Markdown
  def initialize(page)
    @page = page
    super(page.body.html_safe)
  end

  def template
    div(class: 'flow hit', style: "--path: url('/hit/handle?ref=#{@page.request_path}');") do
      super
    end
  end

  def ul
    super(class: 'bullet')
  end
end
