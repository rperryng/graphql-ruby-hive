module GraphQL
  # GraphQL Hive usage collector and schema reporter
  class Hive < GraphQL::Tracing::PlatformTracing
    class Configuration
      attr_accessor :buffer_size, :client_info, :collect_usage, :collect_usage_sampling, :debug, :enabled, :endpoint, :logger, :port, :queue_size, :read_operations, :report_schema, :reporting, :token

      DEFAULT_OPTIONS = {
        buffer_size: 50,
        client_info: nil,
        collect_usage: true,
        collect_usage_sampling: 1.0,
        debug: false,
        enabled: true,
        endpoint: "app.graphql-hive.com",
        logger: nil,
        port: "443",
        queue_size: 1000,
        read_operations: true,
        report_schema: true,
        reporting: {author: nil, commit: nil, service_name: nil, service_url: nil},
        token: nil
      }.freeze

      def initialize(opts = {})
        DEFAULT_OPTIONS.merge(opts).each do |key, value|
          instance_variable_set(:"@#{key}", value)
        end
        setup_logger if @logger.nil?
        validate!
      end

      def validate!
        if !@token && @enabled
          @logger.warn("GraphQL Hive `token` is missing. Disabling Reporting.")
          @enabled = false
          @report_schema = false
        end
        if @report_schema && (@reporting.dig(:author) || !@reporting.dig(:commit))
          @logger.warn("GraphQL Hive `author` and `commit` options are required. Disabling Schema Reporting.")
          @report_schema = false
        end
      end

      private

      def setup_logger
        @logger = Logger.new($stderr)
        original_formatter = Logger::Formatter.new

        @logger.formatter = proc { |severity, datetime, progname, msg|
          msg = msg.respond_to?(:dump) ? msg.dump : msg
          original_formatter.call(severity, datetime, progname, "[hive] #{msg}")
        }

        @logger.level = @debug ? Logger::DEBUG : Logger::INFO
      end
    end
  end
end
