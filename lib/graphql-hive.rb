# frozen_string_literal: true

require "logger"
require "securerandom"

require "graphql-hive/version"
require "graphql-hive/report"
require "graphql-hive/usage_reporter"
require "graphql-hive/client"

require "graphql-hive/operation"
require "graphql-hive/sampler"
require "graphql-hive/sampling/basic_sampler"
require "graphql-hive/sampling/dynamic_sampler"
require "graphql-hive/schema_reporter"
require "graphql-hive/configuration"
require "graphql-hive/tracing"
require "graphql-hive/trace"
require "graphql"

# TODO: remove this because it introduces a race condition in forked processes
at_exit do
  GraphQLHive.configuration&.usage_reporter&.stop
end

module GraphQLHive
  class << self
    attr_accessor :configuration

    def configure
      self.configuration = GraphQLHive::Configuration.new
      yield(configuration) if block_given?
      configuration.validate!
      configuration
    end

    def start
      GraphQLHive.configuration.usage_reporter.start
    end

    def stop
      GraphQLHive.configuration.usage_reporter.stop
    end

    def report_schema_to_hive(schema:, options: {})
      sdl = GraphQL::Schema::Printer.new(schema).print_schema
      SchemaReporter.new(sdl: sdl, options: options).send_report
    rescue => e
      configuration.logger.error("Failed to report schema to Hive: #{e.message}")
      if configuration.debug
        configuration.logger.debug(e.backtrace.join("\n"))
      end
    end
  end
end
