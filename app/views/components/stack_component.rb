# frozen_string_literal: true

class StackComponent < ApplicationComponent
  def template(&)
    div(class: "stack") do
      yield
    end
  end
end
