# frozen_string_literal: true

module Writing
  class ResourcePipeline
    class Invalid < StandardError; end

    LEGACY_KEYS = %w[status published publish_at].freeze
    Target = Data.define(:node_names, :format) do
      def existing_resource(root)
        root.dig(*node_names)&.resources&.format(format)
      end

      def materialize(root)
        node_names.reduce(root) { |parent, name| parent.child(name) }
      end
    end
    Entry = Data.define(:resource, :path, :target)

    def initialize(environment:)
      @environment = environment.to_s
    end

    def process(root)
      entries = writing_resources(root).map do |resource|
        path = Path.new(resource.asset.path)
        target = canonical_target(path) if path.post?

        Entry.new(resource: resource, path: path, target: target)
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
      posts_by_target = entries.select { |entry| entry.path.post? }.group_by(&:target)

      posts_by_target.each do |target, posts|
        existing = target.existing_resource(root)
        sources = posts.map { |entry| entry.path.source_path }
        sources << existing.asset.path.to_s if existing && !posts.any? { |entry| entry.resource.equal?(existing) }
        next unless sources.size > 1

        fail Invalid, "Duplicate canonical writing path #{posts.first.path.request_path}: #{sources.join(", ")}"
      end
    end

    def canonical_target(path)
      sitepress_path = Sitepress::Path.new(path.request_path)
      format = sitepress_path.format || Sitepress::Node::DEFAULT_FORMAT

      Target.new(node_names: sitepress_path.node_names, format: format)
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
      destination = entry.target.materialize(root)

      resource.remove
      resource.format = entry.target.format
      resource.node = destination
    end
  end
end
