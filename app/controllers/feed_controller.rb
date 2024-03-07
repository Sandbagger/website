# frozen_string_literal: true

class FeedController < ApplicationController
  layout -> { ApplicationLayout }

  def index
    respond to do
      format
      format.xml { render locals: {posts:, renderer:} }
    end
  end

  private

  def posts = Sitepress.site.resources.glob("writing/*").select do |resource|
    next if resource.data["publish"].nil?
    resource.data["publish"] <= Date.today
  end.compact.sort_by { |resource| resource.data["publish"] }.reverse

  def renderer = PhlexMarkdownComponent.new
end
