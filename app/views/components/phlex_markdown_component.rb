# frozen_string_literal: true

class PhlexMarkdownComponent < Phlex::Markdown
  def ul
    super(class: 'bullet')
  end
end
