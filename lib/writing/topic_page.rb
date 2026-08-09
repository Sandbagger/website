# frozen_string_literal: true

module Writing
  class TopicPage < Sitepress::Page
    attr_reader :topic

    def initialize(path:, topic:)
      super(path:)
      @topic = topic
      self.data = {
        "layout" => "topic",
        "title" => "Writing about #{topic.label}",
        "topic_label" => topic.label,
        "topic_slug" => topic.slug
      }
    end
  end
end
