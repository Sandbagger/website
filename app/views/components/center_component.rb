# frozen_string_literal: true

class CenterComponent < ApplicationComponent
  def view_template(&)
    div(class: 'center', &)
  end
end
