# frozen_string_literal: true

module Writing
  class Topic < Literal::Data
    class Invalid < StandardError; end

    CANONICAL_LABEL = _Intersection(
      String,
      _Predicate("nonblank String without surrounding whitespace that produces a slug") do |value|
        value.is_a?(String) &&
          value.present? &&
          value == value.strip &&
          value.parameterize.present?
      end
    )

    prop :label, CANONICAL_LABEL, &Immutable

    def self.from(data, source_path:)
      labels = data.fetch("topic") { fail_invalid_metadata!(source_path, "missing topic metadata") }
      unless labels.is_a?(Sitepress::Data::Collection)
        fail_invalid_metadata!(source_path, "topic must be an array")
      end

      labels = labels.to_a
      fail_invalid_metadata!(source_path, "topic must not be empty") if labels.empty?

      topics = labels.each_with_index.map do |label, index|
        validate_member!(label, index, source_path)
        new(label:)
      end
      validate_duplicates!(labels, source_path)

      topics.freeze
    end

    def slug = label.parameterize

    def request_path = "/writing/topics/#{slug}"

    class << self
      private

      def validate_member!(label, index, source_path)
        fail_invalid_member!(source_path, index, "must be a string") unless label.is_a?(String)
        fail_invalid_member!(source_path, index, "must not be blank") if label.blank?
        if label != label.strip
          fail_invalid_member!(source_path, index, "must not have surrounding whitespace")
        end
        return if label.parameterize.present?

        fail_invalid_member!(source_path, index, "must produce a slug")
      end

      def validate_duplicates!(labels, source_path)
        duplicate = labels.group_by(&:downcase).find { |_label, matches| matches.size > 1 }
        return unless duplicate

        fail_invalid_metadata!(source_path, "duplicate topic #{duplicate.first.inspect}")
      end

      def fail_invalid_metadata!(source_path, reason)
        fail Invalid, "Invalid topic metadata in #{source_path.inspect}: #{reason}"
      end

      def fail_invalid_member!(source_path, index, reason)
        fail_invalid_metadata!(source_path, "topic[#{index}] #{reason}")
      end
    end
  end
end
