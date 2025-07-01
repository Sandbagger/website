# frozen_string_literal: true

class CollectionComponent < ApplicationComponent
  include ActionView::Helpers::UrlHelper
  include PageHelper

  def initialize(collection)
    @collection = collection || []
  end

  def template
    ul(class: 'bullet', role: 'list') do
      @collection.each do |resource|
        li(style: "--symbol: '🦄 ';") { link_to_page(resource)}
      end
    end
  end
end
