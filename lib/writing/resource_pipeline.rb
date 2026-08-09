# frozen_string_literal: true

require "pathname"

module Writing
  class ResourcePipeline
    class Invalid < StandardError; end

    LEGACY_KEYS = %w[status published publish_at].freeze
    class Target < Literal::Data
      prop :node_names, _Array(String)
      prop :format, Symbol

      def existing_resource(root)
        root.dig(*node_names)&.resources&.format(format)
      end

      def materialize(root)
        node_names.reduce(root) { |parent, name| parent.child(name) }
      end
    end

    class Entry < Literal::Data
      prop :resource, Sitepress::Resource
      prop :path, Path
      prop :target, _Nilable(Target)
      prop :topics, _Array(Writing::Topic)

      def initialize(resource:, path:, target:, topics:)
        super
      end
    end

    def initialize(environment:, pages_path:)
      @environment = environment.to_s
      @pages_path = Pathname.new(pages_path).expand_path
    end

    def process(root)
      entries = writing_resources(root).map do |resource|
        validate_page_source!(resource)
        path = Path.new(resource.source.path)
        topics = topics_from(resource, path)
        target = canonical_target(path) if path.post?

        Entry.new(resource: resource, path: path, target: target, topics: topics)
      end

      validate_legacy_metadata!(entries)
      validate_slug_uniqueness!(entries)
      validate_topic_registry!(entries)
      validate_collisions!(root, entries)
      entries.each { |entry| apply(root, entry) }

      root
    end

    private

    attr_reader :environment, :pages_path

    def writing_resources(root)
      root.resources.flatten.select { |resource| writing_resource?(resource) }
    end

    def writing_resource?(resource)
      relative_path = Pathname.new(resource.source.path.to_s)
        .expand_path
        .relative_path_from(pages_path)

      relative_path.each_filename.first == "writing"
    end

    def validate_legacy_metadata!(entries)
      entries.each do |entry|
        key = entry.resource.data.keys.map(&:to_s).find { |name| LEGACY_KEYS.include?(name) }
        next unless key

        fail Invalid, "Legacy writing metadata #{key.inspect} in #{entry.path.source_path}"
      end
    end

    def validate_slug_uniqueness!(entries)
      entries.group_by { |entry| entry.path.slug }.each do |slug, duplicates|
        next unless duplicates.size > 1

        sources = duplicates.map { |entry| entry.path.source_path }
        fail Invalid, "Duplicate writing slug #{slug.inspect}: #{sources.join(", ")}"
      end
    end

    def validate_topic_registry!(entries)
      all_occurrences = topic_occurrences(entries)

      all_occurrences.group_by { |topic, _source| topic.label.downcase }.each do |label, occurrences|
        labels = occurrences.map { |topic, _source| topic.label }.uniq
        next if labels.one?

        fail Invalid,
          "Writing topic #{label.inspect} has inconsistent canonical display capitalization: " \
          "#{format_topic_occurrences(occurrences)}"
      end

      all_occurrences.group_by { |topic, _source| topic.slug }.each do |slug, occurrences|
        labels = occurrences.map { |topic, _source| topic.label.downcase }.uniq
        next if labels.one?

        fail Invalid,
          "Writing topic slug collision #{slug.inspect}: #{format_topic_occurrences(occurrences)}"
      end
    end

    def validate_collisions!(root, entries)
      posts_by_target = entries.select { |entry| entry.path.post? }.group_by(&:target)

      posts_by_target.each do |target, posts|
        existing = target.existing_resource(root)
        sources = posts.map { |entry| entry.path.source_path }
        sources << existing.source.path.to_s if existing && !posts.any? { |entry| entry.resource.equal?(existing) }
        next unless sources.size > 1

        fail Invalid, "Duplicate canonical writing path #{posts.first.path.request_path}: #{sources.join(", ")}"
      end
    end

    def canonical_target(path)
      sitepress_path = Sitepress::Path.new(path.request_path)
      format = sitepress_path.format || Sitepress::Node::DEFAULT_FORMAT

      Target.new(node_names: sitepress_path.node_names, format: format)
    end

    def topics_from(resource, path)
      Writing::Topic.from(resource.data, source_path: path.source_path)
    rescue Writing::Topic::Invalid => error
      fail Invalid, error.message, cause: error
    end

    def topic_occurrences(entries)
      entries.flat_map do |entry|
        entry.topics.map { |topic| [topic, entry.path.source_path] }
      end
    end

    def format_topic_occurrences(occurrences)
      occurrences.map { |topic, source| "#{topic.label.inspect} in #{source}" }.uniq.join(", ")
    end

    def apply(root, entry)
      if entry.path.draft?
        if environment == "production"
          entry.resource.remove
        else
          prepare_draft_preview(entry.resource)
        end
      else
        entry.resource.data["publish_at"] = entry.path.publication_date
        move_to_canonical_node(root, entry)
      end
    end

    def prepare_draft_preview(resource)
      return if resource.renderable?

      node = resource.node
      resource.remove
      node.resources.add Sitepress::Resource.new(
        source: resource.source,
        node: node,
        format: :html,
        handler: :markerb,
        mime_type: MIME::Types["text/html"].first
      )
    end

    def move_to_canonical_node(root, entry)
      resource = entry.resource
      destination = entry.target.materialize(root)

      resource.remove
      resource.format = entry.target.format
      resource.node = destination
    end

    def validate_page_source!(resource)
      return if resource.source.is_a?(Sitepress::Page)

      fail Invalid,
        "Writing resource #{resource.source.path} must use Sitepress::Page, " \
        "got #{resource.source.class}"
    end
  end
end
