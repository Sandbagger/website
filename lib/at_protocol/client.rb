# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module AtProtocol
  class Client
    class Error < StandardError; end

    attr_reader :did

    def self.authenticate(pds_url:, identifier:, password:)
      client = new(pds_url:)
      session = client.send(
        :send_request,
        "/xrpc/com.atproto.server.createSession",
        body: {identifier:, password:}
      )
      client.send(:authenticated!, session)
    end

    def initialize(pds_url:)
      @pds_uri = URI.parse(pds_url)
      unless @pds_uri.is_a?(URI::HTTPS) &&
          @pds_uri.host &&
          @pds_uri.userinfo.nil? &&
          ["", "/"].include?(@pds_uri.path) &&
          @pds_uri.query.nil? &&
          @pds_uri.fragment.nil?
        raise ArgumentError, "PDS URL must be an HTTPS origin and contain no credentials"
      end
    rescue URI::InvalidURIError
      raise ArgumentError, "PDS URL must be a valid HTTPS URL"
    end

    def create_record(collection:, record:)
      authenticated_request(
        "/xrpc/com.atproto.repo.createRecord",
        body: {repo: did, collection:, record:}
      )
    end

    def put_record(collection:, rkey:, record:)
      authenticated_request(
        "/xrpc/com.atproto.repo.putRecord",
        body: {repo: did, collection:, rkey:, record:}
      )
    end

    protected

    def send_request(path, body:, access_token: nil)
      request = Net::HTTP::Post.new(path)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{access_token}" if access_token
      request.body = JSON.generate(body)

      response = Net::HTTP.start(
        @pds_uri.host,
        @pds_uri.port,
        use_ssl: true,
        open_timeout: 10,
        read_timeout: 30
      ) { |http| http.request(request) }

      parsed = JSON.parse(response.body)
      return parsed if response.is_a?(Net::HTTPSuccess)

      message = parsed["message"] || parsed["error"] || "HTTP #{response.code}"
      raise Error, "AT Protocol request failed: #{message}"
    rescue JSON::ParserError
      raise Error, "AT Protocol server returned invalid JSON (HTTP #{response&.code || "unknown"})"
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => error
      raise Error, "AT Protocol request failed: #{error.message}"
    end

    private

    def authenticated!(session)
      @did = session.fetch("did")
      @access_token = session.fetch("accessJwt")
      self
    rescue KeyError => error
      raise Error, "AT Protocol session response is missing #{error.key}"
    end

    def authenticated_request(path, body:)
      raise Error, "AT Protocol client is not authenticated" unless @access_token

      send_request(path, body:, access_token: @access_token)
    end
  end
end
