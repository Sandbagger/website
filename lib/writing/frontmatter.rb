# frozen_string_literal: true

module Writing
  class Frontmatter < Literal::Data
    class Invalid < StandardError; end

    KEYS = %w[emoji title topic].freeze

    NONBLANK_STRING = _Intersection(
      String,
      _Predicate("nonblank String without surrounding whitespace") do |value|
        value.is_a?(String) && !value.empty? && value == value.strip
      end
    )
    TOPICS = _Intersection(
      _Array(Writing::Topic),
      _Predicate("non-empty topics with case-insensitively unique labels") do |topics|
        topics.is_a?(Array) &&
          topics.any? &&
          topics.all? { _1.is_a?(Writing::Topic) } &&
          topics.map { _1.label.downcase }.uniq.length == topics.length
      end
    )

    prop :title, NONBLANK_STRING, &Immutable
    prop :topics, TOPICS, &Immutable
    prop :emoji, _Nilable(NONBLANK_STRING), default: nil, &Immutable

    def self.from(data, source_path:)
      validate_keys!(data, source_path)
      title = required_value(data, "title", source_path)
      required_value(data, "topic", source_path)
      validate_text!(title, "title", source_path)
      topics = topics_from(data, source_path)
      emoji = data.key?("emoji") ? data.fetch("emoji") : nil
      validate_text!(emoji, "emoji", source_path) unless emoji.nil?

      new(title:, topics:, emoji:)
    rescue Literal::TypeError => error
      invalid!(source_path, "metadata does not satisfy typed frontmatter", cause: error)
    end

    class << self
      private

      def validate_keys!(data, source_path)
        unknown = data.keys.sort_by(&:to_s).find { |key| !KEYS.include?(key) }
        invalid!(source_path, "unknown metadata #{unknown.inspect}") if unknown
      end

      def required_value(data, key, source_path)
        invalid!(source_path, "missing #{key} metadata") unless data.key?(key)

        data.fetch(key)
      end

      def validate_text!(value, name, source_path)
        invalid!(source_path, "#{name} must be a string") unless value.is_a?(String)
        invalid!(source_path, "#{name} must not be blank") if value.strip.empty?
        return if value == value.strip

        invalid!(source_path, "#{name} must not have surrounding whitespace")
      end

      def topics_from(data, source_path)
        Writing::Topic.from(data, source_path:)
      rescue Writing::Topic::Invalid => error
        prefix = "Invalid topic metadata in #{source_path.inspect}: "
        invalid!(source_path, error.message.delete_prefix(prefix), cause: error)
      end

      def invalid!(source_path, reason, cause: nil)
        error = Invalid.new("Invalid writing frontmatter in #{source_path.inspect}: #{reason}")
        fail error, cause: cause if cause

        fail error
      end
    end
  end
end
