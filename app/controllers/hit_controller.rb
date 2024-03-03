# frozen_string_literal: true

class HitController < ApplicationController
  layout -> { ApplicationLayout }
  
  skip_before_action :verify_authenticity_token, only: [:handle]
  
  def handle
    send_data pixel, 
      type: 'image/gif', 
      disposition: 'inline',
      status: :ok
    
  end

  private 

  def pixel
    # Generate or load a 1x1 transparent pixel data
    Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/8AARgAsAmploiAAAAAASUVORK5CYII=')
  end

  def set_cache_headers
    # Calculate the number of seconds until midnight
    seconds_until_midnight = (DateTime.now.end_of_day - DateTime.now).to_i
    headers['Cache-Control'] = "max-age=#{seconds_until_midnight}, private, must-revalidate"
    headers['Expires'] = 1.day.from_now.at_midnight.httpdate
  end
end
