# frozen_string_literal: true

require "logger"
require "securerandom"

require "graphql-hive/version"
require "graphql-hive/report"
require "graphql-hive/usage_reporter"
require "graphql-hive/client"

require "graphql-hive/sampler"
require "graphql-hive/sampling/basic_sampler"
require "graphql-hive/sampling/dynamic_sampler"
require "graphql-hive/schema_reporter"
require "graphql-hive/configuration"
require "graphql"

module GraphQL
  # GraphQL Hive usage collector and schema reporter
  class Hive < GraphQL::Tracing::PlatformTracing
    @@schema = nil
    @@instance = nil

    self.platform_keys = {
      "lex" => "lex",
      "parse" => "parse",
      "validate" => "validate",
      "analyze_query" => "analyze_query",
      "analyze_multiplex" => "analyze_multiplex",
      "execute_multiplex" => "execute_multiplex",
      "execute_query" => "execute_query",
      "execute_query_lazy" => "execute_query_lazy"
    }

    def initialize(options = {})
      @configuration = GraphQL::Hive::Configuration.new(options)
      super
      @@instance = self
      @client = GraphQL::Hive::Client.new(@configuration)
      sampler = GraphQL::Hive::Sampler.new(
        sampling_options: @configuration.collect_usage_sampling,
        logger: @configuration.logger
      )
      queue = Thread::SizedQueue.new(@configuration.queue_size)
      @usage_reporter = GraphQL::Hive::UsageReporter.new(
        buffer_size: @configuration.buffer_size,
        client_info: @configuration.client_info,
        client: @client,
        sampler: sampler,
        queue: queue,
        logger: @configuration.logger
      )
      report_schema_to_hive if @@schema && @configuration.report_schema
    end

    def self.instance
      @@instance
    end

    def self.use(schema, **kwargs)
      @@schema = schema
      super
    end

    # called on trace events
    def platform_trace(platform_key, _key, data)
      return yield unless should_collect_usage?
      return yield unless platform_key == "execute_multiplex"
      return yield unless data[:multiplex]

      queries = data[:multiplex].queries
      return yield if queries.empty?

      timestamp = generate_timestamp
      results, duration = measure_execution { yield }

      report_usage(timestamp, queries, results, duration)
      results
    rescue => e
      @configuration.logger.error(e)
      yield
    end

    def should_collect_usage?
      @configuration.enabled && @configuration.collect_usage
    end

    def generate_timestamp
      (Time.now.utc.to_f * 1000).to_i
    end

    def measure_execution
      starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      results = yield
      ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      duration = ((ending - starting) * (10**9)).to_i

      [results, duration]
    end

    # compat
    def platform_authorized_key(type)
      "#{type.graphql_name}.authorized.graphql"
    end

    # compat
    def platform_resolve_type_key(type)
      "#{type.graphql_name}.resolve_type.graphql"
    end

    # compat
    def platform_field_key(type, field)
      "graphql.#{type.name}.#{field.name}"
    end

    def on_exit
      @usage_reporter.on_exit
    end

    def start
      @usage_reporter.start
    end

    private

    def report_usage(timestamp, queries, results, duration)
      @configuration.logger.debug("Reporting usage: #{timestamp}, #{queries}, #{results}, #{duration}")
      @usage_reporter.add_operation([timestamp, queries, results, duration])
    end

    def report_schema_to_hive
      sdl = GraphQL::Schema::Printer.new(@sschema).print_schema
      reporter = SchemaReporter.new(sdl, @client, @options.reporting)
      reporter.send_report
    end
  end
end

at_exit do
  GraphQL::Hive.instance&.on_exit
end
