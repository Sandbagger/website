# frozen_string_literal: true

class BoxComponent < ApplicationComponent
  def initialize(invert: false)
    @invert = invert
  end

  def view_template(&)
    div(class: tokens('box', invert?: 'invert'), &)
  end

  private

  def invert? = @invert
end
