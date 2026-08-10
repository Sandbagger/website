# frozen_string_literal: true

module Writing
  class PublicationPolicy
    def initialize(environment:, clock: PublicationClock.new)
      @environment = environment.to_s
      @clock = clock
    end

    def published?(article)
      article.post? && article.publication_date <= today
    end

    def accessible?(article)
      return !production? if article.draft?

      !production? || published?(article)
    end

    private

    attr_reader :clock, :environment

    def production? = environment == "production"

    def today = @today ||= clock.today
  end
end
