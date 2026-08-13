# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class AtProtocol::StandardSiteTest < ActiveSupport::TestCase
  DID = "did:plc:up3nnmpgt6obeinnanblyc6h"

  test "loads an unpublished registry" do
    registry = registry_from({"publicationUri" => nil, "documents" => {}})

    assert_equal DID, registry.did
    assert_equal "https://eurosky.social", registry.pds_url
    assert_nil registry.publication_uri
    assert_nil registry.document_uri("example")
  end

  test "accepts owned publication and document record URIs" do
    publication_uri = "at://#{DID}/site.standard.publication/3abc"
    document_uri = "at://#{DID}/site.standard.document/3def"
    registry = registry_from({"publicationUri" => nil, "documents" => {}})
      .with_publication(publication_uri)
      .with_document("example", document_uri)

    assert_equal publication_uri, registry.publication_uri
    assert_equal document_uri, registry.document_uri("example")
  end

  test "rejects records owned by another DID or in another collection" do
    registry = registry_from({"publicationUri" => nil, "documents" => {}})

    assert_raises(AtProtocol::StandardSite::Invalid) do
      registry.with_publication("at://did:plc:other/site.standard.publication/3abc")
    end
    assert_raises(AtProtocol::StandardSite::Invalid) do
      registry.with_document("example", "at://#{DID}/app.bsky.feed.post/3def")
    end
  end

  test "persists registry updates as stable JSON" do
    Dir.mktmpdir do |directory|
      path = Pathname(directory).join("standard_site.json")
      registry = registry_from(
        {"publicationUri" => nil, "documents" => {}},
        path:
      ).with_publication("at://#{DID}/site.standard.publication/3abc")

      registry.write
      reloaded = AtProtocol::StandardSite::Registry.load(path:)

      assert_equal registry.publication_uri, reloaded.publication_uri
      assert_equal registry.documents, reloaded.documents
    end
  end

  private

  def registry_from(overrides, path: Rails.root.join("tmp/test-standard-site.json"))
    AtProtocol::StandardSite::Registry.new(
      path:,
      data: {
        "did" => DID,
        "pdsUrl" => "https://eurosky.social",
        "publicationUri" => nil,
        "documents" => {}
      }.merge(overrides)
    )
  end
end
