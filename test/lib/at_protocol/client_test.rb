# frozen_string_literal: true

require "test_helper"

class AtProtocol::ClientTest < ActiveSupport::TestCase
  class FakeClient < AtProtocol::Client
    attr_reader :request

    protected

    def send_request(path, body:, access_token: nil)
      @request = {path:, body:, access_token:}
      {
        "did" => "did:plc:example",
        "accessJwt" => "access-token"
      }
    end
  end

  test "authenticates without exposing the app password in client state" do
    client = FakeClient.authenticate(
      pds_url: "https://pds.example.com",
      identifier: "person.example.com",
      password: "app-password"
    )

    assert_equal "did:plc:example", client.did
    assert_equal "/xrpc/com.atproto.server.createSession", client.request.fetch(:path)
    assert_equal({identifier: "person.example.com", password: "app-password"}, client.request.fetch(:body))
    refute_includes client.instance_variables, :@password
  end

  test "rejects a PDS URL that could redirect credentials away from its origin" do
    invalid_urls = [
      "http://pds.example.com",
      "https://user:password@pds.example.com",
      "https://pds.example.com/path",
      "https://pds.example.com?target=other",
      "not a URL"
    ]

    invalid_urls.each do |url|
      assert_raises(ArgumentError) { AtProtocol::Client.new(pds_url: url) }
    end
  end
end
