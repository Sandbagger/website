# frozen_string_literal: true

module Writing
  class PublicationPolicy
    def initialize(environment:, clock: PublicationClock.new)
      @environment = environment.to_s
      @clock = clock
    end

    def published?(path)
      path.post? && path.publication_date <= today
    end

    def accessible?(path)
      return !production? if path.draft?

      !production? || published?(path)
    end

    private

    attr_reader :clock, :environment

    def production? = environment == "production"

    def today = @today ||= clock.today
  end
end
