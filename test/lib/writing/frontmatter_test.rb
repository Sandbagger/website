# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/writing/frontmatter")

class Writing::FrontmatterTest < ActiveSupport::TestCase
  SOURCE_PATH = "app/content/pages/writing/posts/2024-03-10-example.markerb"

  test "converts the closed Sitepress record into an immutable value" do
    title = +"Example"
    first_label = +"Ruby"
    second_label = +"Phlex"
    source_topics = [first_label, second_label]
    emoji = +"🦄"
    data = Sitepress::Data.manage("title" => title, "topic" => source_topics, "emoji" => emoji)

    frontmatter = Writing::Frontmatter.from(data, source_path: SOURCE_PATH)
    equal_frontmatter = Writing::Frontmatter.from(data, source_path: SOURCE_PATH)
    original_hash = frontmatter.hash

    title << " changed"
    first_label << " changed"
    second_label << " changed"
    source_topics.clear
    emoji << " changed"

    assert_equal "Example", frontmatter.title
    assert_equal ["Ruby", "Phlex"], frontmatter.topics.map(&:label)
    assert_equal "🦄", frontmatter.emoji
    assert_equal equal_frontmatter, frontmatter
    assert frontmatter.eql?(equal_frontmatter)
    assert_equal equal_frontmatter.hash, frontmatter.hash
    assert_equal original_hash, frontmatter.hash
    assert_predicate frontmatter, :frozen?
    assert_predicate frontmatter.title, :frozen?
    assert_predicate frontmatter.topics, :frozen?
    assert frontmatter.topics.all?(&:frozen?)
    assert_predicate frontmatter.emoji, :frozen?
    refute_predicate title, :frozen?
    refute_predicate first_label, :frozen?
    refute_predicate second_label, :frozen?
    refute_predicate source_topics, :frozen?
    refute_predicate emoji, :frozen?
  end

  test "omitted emoji defaults to nil through every construction path" do
    data = Sitepress::Data.manage(valid_data.except("emoji"))
    topics = [Writing::Topic.new(label: "Ruby")]

    frontmatters = [
      Writing::Frontmatter.from(data, source_path: SOURCE_PATH),
      Writing::Frontmatter.new(title: "Example", topics:),
      Writing::Frontmatter.from_props(title: "Example", topics:)
    ]

    frontmatters.each { assert_nil _1.emoji }
  end

  test "new and from_props apply every immutable property seal" do
    %i[new from_props].each do |constructor|
      title = +"Example"
      topics = [Writing::Topic.new(label: "Ruby")]
      emoji = +"🦄"
      frontmatter = construct(constructor, title:, topics:, emoji:)
      original_hash = frontmatter.hash

      title << " changed"
      topics.clear
      emoji << " changed"

      assert_equal "Example", frontmatter.title
      assert_equal ["Ruby"], frontmatter.topics.map(&:label)
      assert_equal "🦄", frontmatter.emoji
      assert_equal original_hash, frontmatter.hash
      assert_predicate frontmatter, :frozen?
      assert_predicate frontmatter.title, :frozen?
      assert_predicate frontmatter.topics, :frozen?
      assert_predicate frontmatter.emoji, :frozen?
      refute_same title, frontmatter.title
      refute_same topics, frontmatter.topics
      refute_same emoji, frontmatter.emoji
    end
  end

  test "new and from_props enforce semantic property constraints without leaking method errors" do
    topic = Writing::Topic.new(label: "Ruby")
    duplicate = Writing::Topic.new(label: "ruby")
    invalid_attributes = [
      {title: 1, topics: [topic]},
      {title: "", topics: [topic]},
      {title: " ", topics: [topic]},
      {title: " Example", topics: [topic]},
      {title: "Example ", topics: [topic]},
      {title: "Example", topics: nil},
      {title: "Example", topics: []},
      {title: "Example", topics: ["Ruby"]},
      {title: "Example", topics: [topic, duplicate]},
      {title: "Example", topics: [topic], emoji: 1},
      {title: "Example", topics: [topic], emoji: ""},
      {title: "Example", topics: [topic], emoji: " "},
      {title: "Example", topics: [topic], emoji: " 🦄"},
      {title: "Example", topics: [topic], emoji: "🦄 "}
    ]

    %i[new from_props].product(invalid_attributes).each do |constructor, attributes|
      assert_raises(Literal::TypeError) { construct(constructor, **attributes) }
    end
  end

  test "reports the alphabetically first unknown key" do
    data = valid_data.merge(
      "topics" => ["Ruby"],
      "status" => "published",
      "published" => true,
      "publish_at" => Date.new(2024, 3, 10),
      "date" => Date.new(2024, 3, 10)
    )

    assert_invalid(data, 'unknown metadata "date"')
  end

  test "rejects every legacy metadata name as unknown" do
    %w[date topics status published publish_at].each do |key|
      assert_invalid(valid_data.merge(key => true), "unknown metadata #{key.inspect}")
    end
  end

  test "allows only the exact string source keys" do
    data = {title: "Example", topic: ["Ruby"], emoji: "🦄"}

    assert_invalid(data, "unknown metadata :emoji")
  end

  test "reports missing title before missing topic" do
    assert_invalid({}, "missing title metadata")
    assert_invalid({"title" => "Example"}, "missing topic metadata")
  end

  test "rejects invalid titles" do
    {
      nil => "title must be a string",
      1 => "title must be a string",
      "" => "title must not be blank",
      " " => "title must not be blank",
      " Example" => "title must not have surrounding whitespace",
      "Example " => "title must not have surrounding whitespace"
    }.each do |title, reason|
      assert_invalid(valid_data.merge("title" => title), reason)
    end
  end

  test "rejects an invalid topic container" do
    assert_invalid(valid_data.merge("topic" => nil), "topic must be an array")
    assert_invalid(valid_data.merge("topic" => "Ruby, Phlex"), "topic must be an array")
    assert_invalid(valid_data.merge("topic" => []), "topic must not be empty")
  end

  test "rejects invalid topic members with their index" do
    {
      ["Ruby", 1] => "topic[1] must be a string",
      [""] => "topic[0] must not be blank",
      [" "] => "topic[0] must not be blank",
      [" Ruby"] => "topic[0] must not have surrounding whitespace",
      ["Ruby "] => "topic[0] must not have surrounding whitespace",
      ["!!!"] => "topic[0] must produce a slug"
    }.each do |topics, reason|
      assert_invalid(valid_data.merge("topic" => topics), reason, cause: Writing::Topic::Invalid)
    end
  end

  test "rejects case-insensitive duplicate topics" do
    assert_invalid(
      valid_data.merge("topic" => ["Ruby", "ruby"]),
      'duplicate topic "ruby"',
      cause: Writing::Topic::Invalid
    )
  end

  test "rejects invalid emoji" do
    {
      false => "emoji must be a string",
      1 => "emoji must be a string",
      "" => "emoji must not be blank",
      " " => "emoji must not be blank",
      " 🦄" => "emoji must not have surrounding whitespace",
      "🦄 " => "emoji must not have surrounding whitespace"
    }.each do |emoji, reason|
      assert_invalid(valid_data.merge("emoji" => emoji), reason)
    end
  end

  test "reports topic errors before emoji errors" do
    data = valid_data.merge("topic" => ["Ruby", 1], "emoji" => " ")

    assert_invalid(data, "topic[1] must be a string", cause: Writing::Topic::Invalid)
  end

  test "converts topics exactly once" do
    data = Sitepress::Data.manage(valid_data)
    original_from = Writing::Topic.method(:from)
    calls = 0
    replacement = lambda do |given_data, source_path:|
      calls += 1
      original_from.call(given_data, source_path:)
    end

    with_replaced_singleton_method(Writing::Topic, :from, replacement) do
      Writing::Frontmatter.from(data, source_path: SOURCE_PATH)
    end

    assert_equal 1, calls
  end

  test "preserves Literal type errors raised during typed construction" do
    literal_error = Literal::TypeError.new(
      context: Literal::TypeError::Context.new(expected: String, actual: 1)
    )
    data = Sitepress::Data.manage(valid_data)
    replacement = ->(**) { fail literal_error }

    error = with_replaced_singleton_method(Writing::Frontmatter, :new, replacement) do
      assert_raises(Writing::Frontmatter::Invalid) do
        Writing::Frontmatter.from(data, source_path: SOURCE_PATH)
      end
    end

    assert_equal literal_error, error.cause
    assert_includes error.message, SOURCE_PATH
  end

  test "does not relabel arbitrary internal exceptions" do
    data = Sitepress::Data.manage(valid_data)
    data.define_singleton_method(:keys) { fail KeyError, "internal failure" }

    error = assert_raises(KeyError) do
      Writing::Frontmatter.from(data, source_path: SOURCE_PATH)
    end

    assert_equal "internal failure", error.message
  end

  test "does not relabel Literal type errors from the data interface" do
    internal_error = Literal::TypeError.new(
      context: Literal::TypeError::Context.new(expected: String, actual: 1)
    )
    data = Sitepress::Data.manage(valid_data)
    data.define_singleton_method(:keys) { fail internal_error }

    error = assert_raises(Literal::TypeError) do
      Writing::Frontmatter.from(data, source_path: SOURCE_PATH)
    end

    assert_same internal_error, error
  end

  private

  def valid_data
    {"title" => "Example", "topic" => ["Ruby", "Phlex"], "emoji" => "🦄"}
  end

  def construct(constructor, **attributes)
    case constructor
    when :new
      Writing::Frontmatter.new(**attributes)
    when :from_props
      Writing::Frontmatter.from_props(attributes)
    end
  end

  def assert_invalid(metadata, reason, cause: nil)
    error = assert_raises(Writing::Frontmatter::Invalid) do
      Writing::Frontmatter.from(Sitepress::Data.manage(metadata), source_path: SOURCE_PATH)
    end

    assert_equal "Invalid writing frontmatter in #{SOURCE_PATH.inspect}: #{reason}", error.message
    assert_instance_of cause, error.cause if cause
  end

  def with_replaced_singleton_method(object, name, replacement)
    singleton_class = object.singleton_class
    original_method = object.method(name)
    singleton_class.define_method(name, replacement)
    yield
  ensure
    singleton_class.define_method(name, original_method)
  end
end
