# frozen_string_literal: true

require "test_helper"
require "stringio"
require "tmpdir"

class AtProtocol::StandardSite::PublisherTest < ActiveSupport::TestCase
  DID = "did:plc:up3nnmpgt6obeinnanblyc6h"

  FakeClient = Struct.new(:did, :created, :updated, keyword_init: true) do
    def create_record(collection:, record:)
      created << {collection:, record:}
      {"uri" => "at://#{did}/#{collection}/3created"}
    end

    def put_record(collection:, rkey:, record:)
      updated << {collection:, rkey:, record:}
      {"uri" => "at://#{did}/#{collection}/#{rkey}"}
    end
  end

  Article = Struct.new(:slug, :request_path, :title, :publication_date, :topics, keyword_init: true)

  test "creates publication first and then document metadata" do
    with_registry do |registry|
      client = fake_client
      article = example_article

      result = publisher(client:, registry:, articles: [article]).publish

      assert_equal [
        AtProtocol::StandardSite::PUBLICATION_COLLECTION,
        AtProtocol::StandardSite::DOCUMENT_COLLECTION
      ], client.created.map { _1.fetch(:collection) }
      document = client.created.last.fetch(:record)
      assert_equal result.publication_uri, document.fetch("site")
      assert_equal "/writing/example", document.fetch("path")
      assert_equal "Example", document.fetch("title")
      assert_equal "2026-08-01T00:00:00.000Z", document.fetch("publishedAt")
      assert_equal ["Ruby", "AT Protocol"], document.fetch("tags")
      assert_equal result.document_uri("example"), AtProtocol::StandardSite::Registry.load(path: registry.path).document_uri("example")
    end
  end

  test "updates known records instead of creating duplicates" do
    with_registry(
      "publicationUri" => "at://#{DID}/site.standard.publication/3publication",
      "documents" => {"example" => "at://#{DID}/site.standard.document/3document"}
    ) do |registry|
      client = fake_client

      publisher(client:, registry:, articles: [example_article]).publish

      assert_empty client.created
      assert_equal ["3publication", "3document"], client.updated.map { _1.fetch(:rkey) }
    end
  end

  test "refuses to publish under a different authenticated identity" do
    with_registry do |registry|
      client = fake_client(did: "did:plc:someoneelse")

      assert_raises(AtProtocol::Client::Error) do
        publisher(client:, registry:, articles: []).publish
      end
      assert_empty client.created
    end
  end

  private

  def with_registry(overrides = {})
    Dir.mktmpdir do |directory|
      path = Pathname(directory).join("standard_site.json")
      data = {
        "did" => DID,
        "pdsUrl" => "https://eurosky.social",
        "publicationUri" => nil,
        "documents" => {}
      }.merge(overrides)
      path.write(JSON.pretty_generate(data))
      yield AtProtocol::StandardSite::Registry.load(path:)
    end
  end

  def fake_client(did: DID)
    FakeClient.new(did:, created: [], updated: [])
  end

  def example_article
    Article.new(
      slug: "example",
      request_path: "/writing/example",
      title: "Example",
      publication_date: Date.new(2026, 8, 1),
      topics: [Writing::Topic.new(label: "Ruby"), Writing::Topic.new(label: "AT Protocol")]
    )
  end

  def publisher(client:, registry:, articles:)
    AtProtocol::StandardSite::Publisher.new(
      client:,
      registry:,
      articles:,
      output: StringIO.new
    )
  end
end
