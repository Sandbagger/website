# frozen_string_literal: true

class FeedController < ApplicationController
  layout -> { ApplicationLayout }

  class_attribute :writing_publication_clock,
    instance_writer: false,
    default: Writing::PublicationClock.new
  class_attribute :writing_publication_environment,
    instance_writer: false,
    default: Rails.env
  class_attribute :writing_publication_resources,
    instance_writer: false,
    default: nil

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

  def posts = catalogue.published

  def catalogue
    Writing::Catalogue.new(
      resources: writing_publication_resources || Sitepress.site.resources,
      policy: publication_policy
    )
  end

  def publication_policy
    Writing::PublicationPolicy.new(
      environment: writing_publication_environment,
      clock: writing_publication_clock
    )
  end

  def renderer = ApplicationMarkdown
end
