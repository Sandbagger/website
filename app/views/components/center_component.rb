# frozen_string_literal: true

class CenterComponent < ApplicationComponent
  def template(&)
    div(class: "center") do
      yield
    end
  end
end
