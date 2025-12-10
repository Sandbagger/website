# frozen_string_literal: true

class ClusterComponent < ApplicationComponent
  def view_template(&block)
    ul(class: 'cluster', role: 'list', &block)
  end
end
