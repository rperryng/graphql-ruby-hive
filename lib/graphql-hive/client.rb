# frozen_string_literal: true

require 'net/http'
require 'uri'

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    # API client
    class Client
      def initialize(options)
        @options = options
      end

      def send(path, body, _log_type)
        uri =
          URI::HTTP.build(
            scheme: @options[:port].to_s == '443' ? 'https' : 'http',
            host: @options[:endpoint] || 'app.graphql-hive.com',
            port: @options[:port] || '443',
            path: path
          )

        http = setup_http(uri)
        request = build_request(uri, body)
        response = http.request(request)

        @options[:logger].debug(response.inspect)
        @options[:logger].debug(response.body.inspect)
      rescue StandardError => e
        @options[:logger].fatal("Failed to send data: #{e}")
        raise e
      end

      def setup_http(uri)
        http = ::Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = @options[:port].to_s == '443'
        http.read_timeout = 2
        http
      end

      def build_request(uri, body)
        request = Net::HTTP::Post.new(uri.request_uri)
        request['Authorization'] = @options[:token]
        request['X-Usage-API-Version'] = '2'
        request['content-type'] = 'application/json'
        request['User-Agent'] = "Hive@#{Graphql::Hive::VERSION}"
        request['graphql-client-name'] = 'Hive Ruby Client'
        request['graphql-client-version'] = Graphql::Hive::VERSION
        request.body = JSON.generate(body)
        request
      end
    end
  end
end
