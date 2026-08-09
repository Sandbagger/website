# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/writing/topic")
require Rails.root.join("lib/writing/topic_page")

class Writing::TopicPageTest < ActiveSupport::TestCase
  test "is a Sitepress page" do
    assert_includes Writing.constants, :TopicPage
    assert_operator Writing::TopicPage, :<, Sitepress::Page
  end

  test "stores immutable topic metadata using the shared Markerb template" do
    topic = Writing::Topic.new(label: "Ruby on Rails")
    source = Writing::TopicPage.new(path: template_path, topic: topic)
    node = Sitepress::Node.new.child("writing").child("topics").child(topic.slug)
    resource = Sitepress::Resource.new(source: source, node: node, format: :html)

    assert_same topic, source.topic
    assert_equal template_path, source.path
    assert_equal "topic", source.data["layout"]
    assert_equal "Writing about Ruby on Rails", source.data["title"]
    assert_equal "Ruby on Rails", source.data["topic_label"]
    assert_equal "ruby-on-rails", source.data["topic_slug"]
    assert_instance_of Sitepress::Data::Record, source.data
    assert_predicate source.topic, :frozen?
    assert_equal :html, resource.format
    assert_equal :markerb, resource.handler
    assert_equal "text/html", resource.mime_type.to_s
    assert_predicate resource, :renderable?
  end

  test "uses the shared invisible archive body" do
    source = Writing::TopicPage.new(
      path: template_path,
      topic: Writing::Topic.new(label: "Ruby")
    )

    assert_equal "<!-- Topic archive rows are supplied by the controller. -->\n", source.body
  end

  private

  def template_path
    Rails.root.join("app/content/templates/topic.markerb")
  end
end
