# frozen_string_literal: true

class ClusterComponent < ApplicationComponent
  def view_template(&)
    ul(class: "cluster", role: "list", &)
  end
end
