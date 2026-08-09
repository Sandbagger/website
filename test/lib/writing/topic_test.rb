# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/writing/topic")

class Writing::TopicTest < ActiveSupport::TestCase
  SOURCE_PATH = "app/content/pages/writing/posts/2024-03-10-example.markerb"

  test "is an immutable value object with a derived identity" do
    label = String.new("Ruby on Rails")
    topic = Writing::Topic.new(label: label)
    equal_topic = Writing::Topic.new(label: "Ruby on Rails")

    assert_equal "Ruby on Rails", topic.label
    assert_equal "ruby-on-rails", topic.slug
    assert_equal "/writing/topics/ruby-on-rails", topic.request_path
    assert_equal topic, equal_topic
    assert_predicate topic, :frozen?
    assert_predicate topic.label, :frozen?
    refute_same label, topic.label
  end

  test "converts topic collection metadata into immutable topics" do
    topics = Writing::Topic.from(
      Sitepress::Data.manage("topic" => ["Ruby on Rails", "Phlex"]),
      source_path: SOURCE_PATH
    )

    assert_equal ["Ruby on Rails", "Phlex"], topics.map(&:label)
    assert topics.all?(&:frozen?)
    assert_predicate topics, :frozen?
  end

  test "rejects metadata that does not provide a topic key" do
    assert_invalid({}, "missing topic metadata")
  end

  test "rejects scalar topic metadata without splitting or normalizing it" do
    assert_invalid({ "topic" => "Ruby on Rails, Phlex" }, "must be an array")
  end

  test "rejects empty topic metadata" do
    assert_invalid({ "topic" => [] }, "must not be empty")
  end

  test "rejects non-string topic labels" do
    assert_invalid({ "topic" => ["Ruby", 1] }, "must be a string")
  end

  test "rejects blank topic labels" do
    assert_invalid({ "topic" => [""] }, "must not be blank")
  end

  test "rejects topic labels with surrounding whitespace" do
    assert_invalid({ "topic" => [" Ruby"] }, "must not have surrounding whitespace")
  end

  test "rejects case-insensitive duplicate topic labels" do
    assert_invalid({ "topic" => ["Ruby", "ruby"] }, "duplicate topic")
  end

  test "rejects labels that cannot produce a parameterized slug" do
    assert_invalid({ "topic" => ["!!!"] }, "must produce a slug")
  end

  private

  def assert_invalid(metadata, reason)
    error = assert_raises(Writing::Topic::Invalid) do
      Writing::Topic.from(Sitepress::Data.manage(metadata), source_path: SOURCE_PATH)
    end

    assert_includes error.message, SOURCE_PATH
    assert_includes error.message, reason
  end
end
