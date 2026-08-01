# frozen_string_literal: true

module Writing
  class Catalogue
    Entry = Data.define(:resource, :path)

    def initialize(resources:, policy:)
      @resources = resources
      @policy = policy
    end

    def published(exclude: nil)
      entries
        .select { |entry| policy.published?(entry.path) }
        .reject { |entry| entry.resource.request_path == exclude }
        .sort_by { |entry| entry.path.publication_date }
        .reverse
        .map(&:resource)
    end

    private

    attr_reader :policy, :resources

    def entries
      resources.filter_map do |resource|
        path = Path.new(resource.asset.path)
        Entry.new(resource:, path:)
      rescue Path::Invalid
        nil
      end
    end
  end
end
