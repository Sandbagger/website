# frozen_string_literal: true

class ClusterComponent < ApplicationComponent
  def template
    ul(class: "cluster", role: "list") do
      yield
    end
  end
end
