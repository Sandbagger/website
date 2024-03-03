# frozen_string_literal: true

class CollectionComponent < ApplicationComponent
  include ActionView::Helpers::UrlHelper
  include PageHelper

  def initialize(collection)
    @collection = collection || []
  end

  def template
    ul do
      @collection.each do |resource|
        li do
          link_to_page(resource)
        end
      end
    end
  end
end
