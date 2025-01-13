# frozen_string_literal: true

require "net/http"
require "uri"

module GraphQLHive
  # API client
  class Client
    attr_accessor :logger
    def initialize(port:, endpoint:, token:, logger:)
      @port = port.to_s
      @scheme = (@port == "443") ? "https" : "http"
      @host = endpoint
      @token = token
      @use_ssl = @port == "443"
      @logger = logger
    end

    def send(path, body, _log_type)
      uri =
        URI::HTTP.build(
          scheme: @scheme,
          host: @host,
          port: @port,
          path: path
        )

      http = setup_http(uri)
      request = build_request(uri, body)
      response = http.request(request)

      code = response.code.to_i
      if code >= 400 && code < 500
        error_message = "Unsuccessful response: #{response.code} - #{response.message}"
        @logger.warn("#{error_message} #{extract_error_details(response)}")
      end

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
      request["User-Agent"] = "Hive@#{GraphQLHive::VERSION}"
      request["graphql-client-name"] = "Hive Ruby Client"
      request["graphql-client-version"] = GraphQLHive::VERSION
      request.body = JSON.generate(body)
      request
    end

    def extract_error_details(response)
      parsed_body = JSON.parse(response.body)
      return unless parsed_body.is_a?(Hash) && parsed_body["errors"].is_a?(Array)
      parsed_body["errors"].map { |error| "{ path: #{error["path"]}, message: #{error["message"]} }" }.join(", ")
    rescue JSON::ParserError
      "Could not parse response from Hive"
    end
  end
end
