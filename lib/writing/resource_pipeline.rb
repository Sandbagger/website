# frozen_string_literal: true

module Writing
  class ResourcePipeline
    class Invalid < StandardError; end

    LEGACY_KEYS = %w[status published publish_at].freeze
    Entry = Data.define(:resource, :path)

    def initialize(environment:)
      @environment = environment.to_s
    end

    def process(root)
      entries = writing_resources(root).map do |resource|
        Entry.new(resource: resource, path: Path.new(resource.asset.path))
      end

      validate_legacy_metadata!(entries)
      validate_collisions!(root, entries)
      entries.each { |entry| apply(root, entry) }

      root
    end

    private

    attr_reader :environment

    def writing_resources(root)
      root.resources.flatten.select do |resource|
        resource.asset.path.to_s.match?(%r{(?:\A|/)writing/(?:posts|drafts)/})
      end
    end

    def validate_legacy_metadata!(entries)
      entries.each do |entry|
        key = entry.resource.data.keys.map(&:to_s).find { |name| LEGACY_KEYS.include?(name) }
        next unless key

        fail Invalid, "Legacy writing metadata #{key.inspect} in #{entry.path.source_path}"
      end
    end

    def validate_collisions!(root, entries)
      posts_by_path = entries.select { |entry| entry.path.post? }.group_by { |entry| entry.path.request_path }

      posts_by_path.each do |request_path, posts|
        existing = root.get(request_path)
        sources = posts.map { |entry| entry.path.source_path }
        sources << existing.asset.path.to_s if existing && !posts.any? { |entry| entry.resource.equal?(existing) }
        next unless sources.size > 1

        fail Invalid, "Duplicate canonical writing path #{request_path}: #{sources.join(", ")}"
      end
    end

    def apply(root, entry)
      if entry.path.draft?
        entry.resource.remove if environment == "production"
      else
        entry.resource.data["publish_at"] = entry.path.publication_date
        move_to_canonical_node(root, entry)
      end
    end

    def move_to_canonical_node(root, entry)
      resource = entry.resource
      destination = root.child("writing").child(entry.path.slug)

      resource.remove
      resource.format = destination.default_format
      resource.node = destination
    end
  end
end
