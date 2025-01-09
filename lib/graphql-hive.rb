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

module GraphQLHive
  module Trace
    def initialize(multiplex: nil, query: nil, **options)
      # TODO make configuration a singleton
      @configuration = GraphQLHive::Configuration.new(options)
      GraphQLHive::Tracing.instance.configuration = @configuration
      @tracer = GraphQLHive::Tracing.instance
      # TODO put in configuration so we don't call this on every trace
      report_schema_to_hive(options[:schema])
      super
    end

    def execute_multiplex(multiplex:)
      return super unless should_collect_usage?

      @tracer.trace(resource: multiplex.queries.first.to_s, queries: multiplex.queries) do
        super
      end
    end

    def should_collect_usage?
      @configuration.enabled? && @configuration.collect_usage?
    end

    def report_schema_to_hive(schema)
      return if schema.nil? || !@configuration.report_schema

      sdl = GraphQL::Schema::Printer.new(schema).print_schema
      SchemaReporter.new(sdl, @configuration.client, @options.reporting).send_report
    end
  end
end

module GraphQLHive
  class Tracing
    include Singleton

    attr_accessor :configuration

    Operation = Data.define(:timestamp, :queries, :results, :elapsed_ns)

    def initialize
      @usage_reporter = nil
    end

    def trace(resource:, queries:)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      all_results = yield
      elapsed_ns = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1e9).to_i

      usage_reporter.add_operation(
        Operation.new(
          Time.now.to_i * 1000,
          queries,
          all_results.map(&:to_h),
          elapsed_ns
        )
      )

      all_results
    end

    def stop
      return if @usage_reporter.nil?
      usage_reporter.stop
    end
    alias_method :on_exit, :stop

    def start
      usage_reporter.start
    end
    alias_method :on_start, :start

    private

    def usage_reporter
      @usage_reporter ||= GraphQLHive::UsageReporter.new(
        buffer_size: configuration.buffer_size,
        client_info: configuration.client_info,
        client: configuration.client,
        sampler: GraphQLHive::Sampler.new(
          sampling_options: configuration.collect_usage_sampling,
          logger: configuration.logger
        ),
        queue: Thread::SizedQueue.new(configuration.queue_size),
        logger: configuration.logger
      )
    end
  end
end

at_exit do
  GraphQLHive::Tracing.instance&.stop
end
