# frozen_string_literal: true

class StackComponent < ApplicationComponent
  def view_template(&)
    div(class: 'stack', &)
  end
end
