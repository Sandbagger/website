# frozen_string_literal: true

require "pathname"

module Writing
  class ResourcePipeline
    class Invalid < StandardError; end

    class Target < Literal::Data
      prop :node_names, _Array(String), &DeepImmutable
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
      prop :article, Writing::Article
      prop :target, _Nilable(Target)
    end

    def initialize(environment:, pages_path:, topic_template_path:)
      @environment = environment.to_s
      @pages_path = Pathname.new(pages_path).expand_path
      @topic_template_path = Pathname.new(topic_template_path).expand_path
    end

    def process(root)
      entries = writing_resources(root).map do |resource|
        validate_page_source!(resource)
        article = article_from(resource)
        target = canonical_target(article) if article.post?

        Entry.new(resource:, article:, target:)
      end

      validate_slug_uniqueness!(entries)
      validate_topic_registry!(entries)
      topic_plan = planned_topics(entries)
      topics = generated_topics(entries)
      validate_topic_template!
      validate_collisions!(root, entries)
      validate_topic_collisions!(root, entries, topic_plan)
      entries.each { |entry| apply(root, entry) }
      topics.each { |topic| generate_topic(root, topic) }

      root
    end

    private

    attr_reader :environment, :pages_path, :topic_template_path

    def writing_resources(root)
      root.resources.flatten.select { |resource| writing_resource?(resource) }
    end

    def writing_resource?(resource)
      relative_path = Pathname.new(resource.source.path.to_s)
        .expand_path
        .relative_path_from(pages_path)

      relative_path.each_filename.first == "writing"
    end

    def validate_slug_uniqueness!(entries)
      entries.group_by { |entry| entry.article.slug }.each do |slug, duplicates|
        next unless duplicates.size > 1

        sources = duplicates.map { |entry| entry.article.source_path }
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
      posts_by_target = entries.select { |entry| entry.article.post? }.group_by(&:target)

      posts_by_target.each do |target, posts|
        existing = target.existing_resource(root)
        sources = posts.map { |entry| entry.article.source_path }
        sources << existing.source.path.to_s if existing && !posts.any? { |entry| entry.resource.equal?(existing) }
        next unless sources.size > 1

        fail Invalid,
          "Duplicate canonical writing path #{posts.first.article.request_path}: #{sources.join(", ")}"
      end
    end

    def validate_topic_template!
      return if topic_template_path.file?

      fail Invalid, "Writing topic template must be a file: #{topic_template_path}"
    end

    def validate_topic_collisions!(root, entries, topics)
      topics.each do |topic|
        existing = topic_target(topic).existing_resource(root)
        next unless existing

        fail Invalid,
          "Generated writing topic path #{topic.request_path} for slug #{topic.slug.inspect} " \
          "from #{topic_sources(entries, topic).join(", ")} collides with #{existing.source.path}"
      end
    end

    def canonical_target(article)
      sitepress_path = Sitepress::Path.new(article.request_path)
      format = sitepress_path.format || Sitepress::Node::DEFAULT_FORMAT

      Target.new(node_names: sitepress_path.node_names, format: format)
    end

    def topic_target(topic)
      path = Sitepress::Path.new(topic.request_path)
      Target.new(
        node_names: path.node_names,
        format: path.format || Sitepress::Node::DEFAULT_FORMAT
      )
    end

    def article_from(resource)
      Writing::Article.from(resource)
    rescue Writing::Frontmatter::Invalid => error
      fail Invalid, error.message, cause: error
    end

    def topic_occurrences(entries)
      entries.flat_map do |entry|
        entry.article.topics.map { |topic| [topic, entry.article.source_path] }
      end
    end

    def generated_topics(entries)
      planned_topics(entries.select { |entry| entry.article.post? || environment != "production" })
    end

    def planned_topics(entries)
      entries.flat_map { |entry| entry.article.topics }.uniq(&:slug)
    end

    def topic_sources(entries, topic)
      entries.flat_map do |entry|
        next [] unless entry.article.topics.any? { |entry_topic| entry_topic.slug == topic.slug }

        entry.article.source_path
      end
    end

    def format_topic_occurrences(occurrences)
      occurrences.map { |topic, source| "#{topic.label.inspect} in #{source}" }.uniq.join(", ")
    end

    def apply(root, entry)
      if entry.article.draft?
        if environment == "production"
          entry.resource.remove
        else
          prepare_draft_preview(entry.resource)
        end
      else
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

    def generate_topic(root, topic)
      target = topic_target(topic)
      node = target.materialize(root)
      node.resources.add Sitepress::Resource.new(
        source: Writing::TopicPage.new(path: topic_template_path, topic: topic),
        node: node,
        format: target.format
      )
    end

    def validate_page_source!(resource)
      return if resource.source.is_a?(Sitepress::Page)

      fail Invalid,
        "Writing resource #{resource.source.path} must use Sitepress::Page, " \
        "got #{resource.source.class}"
    end
  end
end
