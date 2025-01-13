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
require "graphql-hive/tracing"
require "graphql-hive/trace"
require "graphql"

at_exit do
  GraphQLHive.configuration.usage_reporter.stop
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
  end
end
