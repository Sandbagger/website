# frozen_string_literal: true

class CollectionComponent < ApplicationComponent
  include ActionView::Helpers::UrlHelper
  include PageHelper

  def initialize(collection, context: :archive)
    @collection = collection || []
    @context = context.to_sym
  end

  def view_template
    h3(class: "cluster") do
      "Latest ✍️"
    end

    ul(class: "bullet flow", role: "list") do
      @collection.each do |resource|
        emoji = resource.data.fetch("emoji", "🦄 ")
        li(style: "--symbol: '#{emoji} ';") { link_to_page(resource) }
      end
    end
  end
end
