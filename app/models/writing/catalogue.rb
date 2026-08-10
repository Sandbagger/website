# frozen_string_literal: true

module Writing
  class Catalogue
    def initialize(resources:, policy:)
      @resources = resources
      @policy = policy
    end

    def published(exclude: nil, topic: nil)
      validate_topic!(topic)

      articles
        .select { |article| policy.published?(article) }
        .then { |published_articles| topic.nil? ? published_articles : published_articles.select { |article| article.topics.include?(topic) } }
        .reject { |article| article.request_path == exclude }
        .sort_by(&:publication_date)
        .reverse
    end

    private

    attr_reader :policy, :resources

    def validate_topic!(topic)
      return if topic.nil? || topic.is_a?(Writing::Topic)

      fail ArgumentError, "topic must be a Writing::Topic or nil"
    end

    def articles
      resources.filter_map do |resource|
        Writing::Article.from(resource)
      rescue Path::Invalid
        nil
      end
    end
  end
end
