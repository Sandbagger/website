# frozen_string_literal: true

module Writing
  class Catalogue
    class Entry < Literal::Data
      prop :resource, Sitepress::Resource
      prop :path, Path
      prop :topics, _Array(Writing::Topic)

      def after_initialize
        @topics = topics.dup.freeze
      end
    end

    def initialize(resources:, policy:)
      @resources = resources
      @policy = policy
    end

    def published(exclude: nil, topic: nil)
      entries
        .select { |entry| policy.published?(entry.path) }
        .then { |published_entries| topic ? published_entries.select { |entry| entry.topics.include?(topic) } : published_entries }
        .reject { |entry| entry.resource.request_path == exclude }
        .sort_by { |entry| entry.path.publication_date }
        .reverse
        .map(&:resource)
    end

    private

    attr_reader :policy, :resources

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
