# frozen_string_literal: true

class TopicLinksComponent < ApplicationComponent
  def initialize(topics)
    @topics = topics
  end

  def view_template
    @topics.each_with_index do |topic, index|
      plain " · " unless index.zero?
      a(href: topic.request_path) { topic.label }
    end
  end
end
