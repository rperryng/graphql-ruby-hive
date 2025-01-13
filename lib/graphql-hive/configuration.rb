module GraphQLHive
  class Configuration
    attr_accessor :buffer_size,
      :client,
      :client_info,
      :collect_usage,
      :collect_usage_sampling,
      :debug,
      :enabled,
      :logger,
      :queue_size,
      :read_operations,
      :schema,
      :token

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
      token: nil
    }.freeze

    def initialize(opts = {})
      DEFAULT_OPTIONS.merge(opts).each do |key, value|
        instance_variable_set(:"@#{key}", value)
      end
      # TODO Allow for custom client
      @client = GraphQLHive::Client.new(
        port: @port,
        endpoint: @endpoint,
        token: @token,
        logger: @logger
      )
    end

    alias_method :collect_usage?, :collect_usage
    alias_method :enabled?, :enabled

    def validate!
      setup_logger if @logger.nil?
      @client.logger = @logger if @client.logger.nil?
      if !@token && @enabled
        @logger.warn("GraphQL Hive `token` is missing. Disabling Reporting.")
        @enabled = false
      end
    end

    def usage_reporter
      @usage_reporter ||= GraphQLHive::UsageReporter.new(
        buffer_size: buffer_size,
        client_info: client_info,
        client: client,
        sampler: GraphQLHive::Sampler.new(
          sampling_options: collect_usage_sampling,
          logger: logger
        ),
        queue: Thread::SizedQueue.new(queue_size),
        logger: logger
      )
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
