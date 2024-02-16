# frozen_string_literal: true

class HomepageController < ApplicationController
  layout -> { ApplicationLayout }

  def index
    render Homepage::IndexView.new
  end
end
