# frozen_string_literal: true

module Writing
  class PublicationClock
    TIME_ZONE = ActiveSupport::TimeZone["Europe/Brussels"]

    def today(at: Time.current)
      at.in_time_zone(TIME_ZONE).to_date
    end
  end
end
