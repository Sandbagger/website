# frozen_string_literal: true

class HitController < ApplicationController
  layout -> { ApplicationLayout }

  skip_before_action :verify_authenticity_token, only: [:handle]
  before_action :set_cache_headers
  before_action :unique_id, only: [:handle]

  def handle
    Hit.create(
      unique_user_id: cookies[:unique_id],
      user_agent: request.user_agent,
      page: request.query_parameters[:ref],
      referer: request.referer,
      metadata: request.query_parameters,
      path: params[:ref]
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
