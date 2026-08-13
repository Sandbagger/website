# frozen_string_literal: true

require "json"
require "pathname"
require "tempfile"
require "uri"

module AtProtocol
  module StandardSite
    PUBLICATION_COLLECTION = "site.standard.publication"
    DOCUMENT_COLLECTION = "site.standard.document"
    DID_PATTERN = /\Adid:(?:plc|web):[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-]\z/
    AT_URI_PATTERN = /\Aat:\/\/(did:(?:plc|web):[^\/]+)\/([a-z][a-z0-9.-]+)\/([A-Za-z0-9.\-_:~]+)\z/

    class Invalid < StandardError; end

    class Registry
      attr_reader :did, :pds_url, :publication_uri, :documents, :path

      def self.load(path: Rails.root.join("config/standard_site.json"))
        new(path:, data: JSON.parse(Pathname(path).read))
      rescue JSON::ParserError => error
        raise Invalid, "Invalid Standard.site registry JSON: #{error.message}"
      end

      def initialize(path:, data:)
        @path = Pathname(path)
        @did = data.fetch("did")
        @pds_url = data.fetch("pdsUrl")
        @publication_uri = data.fetch("publicationUri")
        @documents = data.fetch("documents").dup.freeze

        validate!
        freeze
      rescue KeyError => error
        raise Invalid, "Missing Standard.site registry key: #{error.key}"
      end

      def document_uri(slug) = documents[slug]

      def with_publication(uri)
        validate_record_uri!(uri, collection: PUBLICATION_COLLECTION)
        with("publicationUri" => uri)
      end

      def with_document(slug, uri)
        validate_slug!(slug)
        validate_record_uri!(uri, collection: DOCUMENT_COLLECTION)
        with("documents" => documents.merge(slug => uri))
      end

      def write
        path.dirname.mkpath
        tempfile = Tempfile.new([path.basename.to_s, ".tmp"], path.dirname.to_s)
        tempfile.write(JSON.pretty_generate(to_h) + "\n")
        tempfile.flush
        tempfile.fsync
        tempfile.close
        File.rename(tempfile.path, path)
        self
      ensure
        tempfile&.close!
      end

      private

      def validate!
        raise Invalid, "Invalid Standard.site DID: #{did.inspect}" unless DID_PATTERN.match?(did)

        uri = URI.parse(pds_url)
        unless uri.is_a?(URI::HTTPS) &&
            uri.host &&
            uri.userinfo.nil? &&
            ["", "/"].include?(uri.path) &&
            uri.query.nil? &&
            uri.fragment.nil?
          raise Invalid, "Standard.site PDS URL must be an HTTPS origin"
        end

        validate_record_uri!(publication_uri, collection: PUBLICATION_COLLECTION) if publication_uri
        unless documents.is_a?(Hash) && documents.keys.all?(String) && documents.values.all?(String)
          raise Invalid, "Standard.site documents must be a string-to-string object"
        end

        documents.each do |slug, record_uri|
          validate_slug!(slug)
          validate_record_uri!(record_uri, collection: DOCUMENT_COLLECTION)
        end
      rescue URI::InvalidURIError
        raise Invalid, "Standard.site PDS URL must be an HTTPS origin"
      end

      def validate_slug!(slug)
        return if slug.present? && slug == slug.parameterize

        raise Invalid, "Invalid Standard.site document slug: #{slug.inspect}"
      end

      def validate_record_uri!(uri, collection:)
        match = AT_URI_PATTERN.match(uri)
        unless match && match[1] == did && match[2] == collection
          raise Invalid, "Invalid #{collection} URI for #{did}: #{uri.inspect}"
        end
      end

      def with(changes)
        self.class.new(path:, data: to_h.merge(changes))
      end

      def to_h
        {
          "did" => did,
          "pdsUrl" => pds_url,
          "publicationUri" => publication_uri,
          "documents" => documents.sort.to_h
        }
      end
    end

    def self.registry = Registry.load
  end
end
