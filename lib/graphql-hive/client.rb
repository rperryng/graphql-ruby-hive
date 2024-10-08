# frozen_string_literal: true

require "net/http"
require "uri"

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    # API client
    class Client
      def initialize(token:, logger:, port: "443", endpoint: "app.graphql-hive.com")
        @port = port.to_s
        @use_ssl = port == "443"
        @scheme = @use_ssl ? "https" : "http"
        @endpoint = endpoint
        @token = token
        @logger = logger
      end

      def send(path, body, _log_type)
        uri =
          URI::HTTP.build(
            scheme: @http_scheme,
            host: @endpoint,
            port: @port,
            path: path
          )

        http = setup_http(uri)
        request = build_request(uri, body)
        response = http.request(request)

        @logger.debug(response.inspect)
        @logger.debug(response.body.inspect)
      rescue => e
        @logger.fatal("Failed to send data: #{e}")
      end

      def setup_http(uri)
        http = ::Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = @use_ssl
        http.read_timeout = 2
        http
      end

      def build_request(uri, body)
        request = Net::HTTP::Post.new(uri.request_uri)
        request["Authorization"] = @token
        request["X-Usage-API-Version"] = "2"
        request["content-type"] = "application/json"
        request["User-Agent"] = "Hive@#{Graphql::Hive::VERSION}"
        request["graphql-client-name"] = "Hive Ruby Client"
        request["graphql-client-version"] = Graphql::Hive::VERSION
        request.body = JSON.generate(body)
        request
      end
    end
  end
end
