# frozen_string_literal: true

module Writing
  class Topic < Literal::Data
    class Invalid < StandardError; end

    prop :label, String

    def self.from(data, source_path:)
      labels = data.fetch("topic") { fail_invalid_metadata!(source_path, "missing topic metadata") }
      unless labels.is_a?(Sitepress::Data::Collection)
        fail_invalid_metadata!(source_path, "topic must be an array")
      end

      labels = labels.to_a
      fail_invalid_metadata!(source_path, "topic must not be empty") if labels.empty?

      validate_members!(labels, source_path)
      validate_duplicates!(labels, source_path)

      labels.each_with_index.map do |label, index|
        new(label: label)
      rescue Invalid => error
        reason = error.message.delete_prefix("topic label ")
        fail_invalid_metadata!(source_path, "topic[#{index}] #{reason}")
      end.freeze
    end

    def slug = label.parameterize

    def request_path = "/writing/topics/#{slug}"

    private

    def after_initialize
      fail Invalid, "topic label must not be blank" if label.blank?
      fail Invalid, "topic label must not have surrounding whitespace" if label != label.strip
      fail Invalid, "topic label must produce a slug" if slug.empty?

      @label = label.dup.freeze
    end

    class << self
      private

      def validate_members!(labels, source_path)
        labels.each_with_index do |label, index|
          next if label.is_a?(String)

          fail_invalid_metadata!(source_path, "topic[#{index}] must be a string")
        end
      end

      def validate_duplicates!(labels, source_path)
        duplicate = labels.group_by(&:downcase).find { |_label, matches| matches.size > 1 }
        return unless duplicate

        fail_invalid_metadata!(source_path, "duplicate topic #{duplicate.first.inspect}")
      end

      def fail_invalid_metadata!(source_path, reason)
        fail Invalid, "Invalid topic metadata in #{source_path.inspect}: #{reason}"
      end
    end
  end
end
