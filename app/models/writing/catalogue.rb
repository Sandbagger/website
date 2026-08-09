# frozen_string_literal: true

module Writing
  class Catalogue
    class Entry < Literal::Data
      prop :resource, Sitepress::Resource
      prop :path, Path
      prop :topics, _Array(Writing::Topic), &Immutable
    end

    def initialize(resources:, policy:)
      @resources = resources
      @policy = policy
    end

    def published(exclude: nil, topic: nil)
      validate_topic!(topic)

      entries
        .select { |entry| policy.published?(entry.path) }
        .then { |published_entries| topic.nil? ? published_entries : published_entries.select { |entry| entry.topics.include?(topic) } }
        .reject { |entry| entry.resource.request_path == exclude }
        .sort_by { |entry| entry.path.publication_date }
        .reverse
        .map(&:resource)
    end

    private

    attr_reader :policy, :resources

    def validate_topic!(topic)
      return if topic.nil? || topic.is_a?(Writing::Topic)

      fail ArgumentError, "topic must be a Writing::Topic or nil"
    end

    def entries
      resources.filter_map do |resource|
        path = Path.new(resource.source.path)
        topics = Writing::Topic.from(resource.data, source_path: resource.source.path)
        Entry.new(resource:, path:, topics:)
      rescue Path::Invalid
        nil
      end
    end
  end
end
