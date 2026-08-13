# frozen_string_literal: true

require "time"

module AtProtocol
  module StandardSite
    class Publisher
      SITE_URL = "https://williamneal.dev"
      PUBLICATION_NAME = "William Neal"
      PUBLICATION_DESCRIPTION = "Engineering, writing, and enthusiastic generalism from Brussels."

      def initialize(client:, registry:, articles:, output: $stdout)
        @client = client
        @registry = registry
        @articles = articles
        @output = output
      end

      def publish
        validate_identity!
        publish_publication
        articles.each { |article| publish_document(article) }
        registry
      end

      private

      attr_reader :articles, :client, :output
      attr_accessor :registry

      def validate_identity!
        return if client.did == registry.did

        raise AtProtocol::Client::Error,
          "Authenticated DID #{client.did} does not own the configured publication (#{registry.did})"
      end

      def publish_publication
        response = upsert(
          collection: PUBLICATION_COLLECTION,
          uri: registry.publication_uri,
          record: publication_record
        )
        @registry = registry.with_publication(response.fetch("uri")).write
        output.puts "publication #{response.fetch("uri")}"
      end

      def publish_document(article)
        response = upsert(
          collection: DOCUMENT_COLLECTION,
          uri: registry.document_uri(article.slug),
          record: document_record(article)
        )
        @registry = registry.with_document(article.slug, response.fetch("uri")).write
        output.puts "document #{response.fetch("uri")}"
      end

      def upsert(collection:, uri:, record:)
        return client.create_record(collection:, record:) unless uri

        client.put_record(collection:, rkey: record_key(uri), record:)
      end

      def publication_record
        {
          "$type" => PUBLICATION_COLLECTION,
          "url" => SITE_URL,
          "name" => PUBLICATION_NAME,
          "description" => PUBLICATION_DESCRIPTION,
          "preferences" => {"showInDiscover" => true}
        }
      end

      def document_record(article)
        {
          "$type" => DOCUMENT_COLLECTION,
          "site" => registry.publication_uri,
          "path" => article.request_path,
          "title" => article.title,
          "publishedAt" => Time.utc(
            article.publication_date.year,
            article.publication_date.month,
            article.publication_date.day
          ).iso8601(3),
          "tags" => article.topics.map(&:label)
        }
      end

      def record_key(uri) = uri.split("/").last
    end
  end
end
