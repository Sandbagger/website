# frozen_string_literal: true

class BoxComponent < ApplicationComponent
  def initialize(invert: false)
    @invert = invert
  end

  def template(&)
    div(class: tokens("box", invert?: "invert")) do
      yield
    end
  end

  private

  def invert? = @invert
end
