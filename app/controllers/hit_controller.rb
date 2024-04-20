# frozen_string_literal: true

class HitController < ApplicationController
  layout -> { ApplicationLayout }

  skip_before_action :verify_authenticity_token, only: [:handle]
  before_action :set_cache_headers
  before_action :unique_id, only: [:handle]

  def handle
    Hit.create!(
      unique_user_id: cookies[:unique_id],
      user_agent: request.user_agent,
      # TODO: get internal referer to work
      # referer: request.query_parameters[:ref],
      metadata: request.query_parameters,
      # using the CSS only option for now
      path: request.query_parameters[:path],
    )

    send_data pixel,
      type: "image/gif",
      disposition: "inline",
      status: :ok
  end

  private

  def pixel
    Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/8AARgAsAmploiAAAAAASUVORK5CYII=")
  end

  def set_cache_headers
    pp 'set_cache_headers'
    # set private cache instead of IP address to handle repeated views
    page_key = params[:ref] || request.path
    seconds_until_midnight = (DateTime.now.end_of_day - DateTime.now).to_i
    headers["Cache-Control"] = "max-age=#{seconds_until_midnight}, private, must-revalidate"
    headers["Expires"] = 1.day.from_now.at_midnight.httpdate
    # page key is crucial to ensure that the cache is unique per page
    headers["Vary"] = "Accept, Accept-Encoding, #{page_key}"
  end

  def unique_id
    cookies.permanent[:unique_id] ||= SecureRandomWrapper.hex(10).to_s
  end
end
