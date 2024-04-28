# frozen_string_literal: true

class FeedController < ApplicationController
  layout -> { ApplicationLayout }
  def index
    respond_to do |format|
      format.html { head :no_content } # Add this line
      format.xml { render locals: {posts:, renderer:}, layout: false }
    rescue => e
      Rails.logger.error "Failed to render XML: #{e.message}"
      render xml: "<error>Internal Server Error</error>", status: :internal_server_error
    end
  end

  private

  def posts = Sitepress.site.resources.glob("writing/*").select do |resource|
    next if resource.data["publish_at"].nil?
    resource.data["publish_at"] <= Date.today
  end.compact.sort_by { |resource| resource.data["publish_at"] }.reverse

  def renderer = ApplicationMarkdown
end
