# frozen_string_literal: true

class HitController < ApplicationController
  layout -> { ApplicationLayout }

  skip_before_action :verify_authenticity_token, only: [:handle]
  before_action :set_cache_headers

  def handle
    Rails.logger.info "Page view: #{request.query_parameters.inspect}, User Agent: #{request.user_agent}, Referer: #{request.referer}"

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
    seconds_until_midnight = (DateTime.now.end_of_day - DateTime.now).to_i
    headers["Cache-Control"] = "max-age=#{seconds_until_midnight}, private, must-revalidate"
    headers["Expires"] = 1.day.from_now.at_midnight.httpdate
  end
end
