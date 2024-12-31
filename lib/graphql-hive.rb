# frozen_string_literal: true

require "logger"
require "securerandom"

require "graphql-hive/version"
require "graphql-hive/usage_reporter"
require "graphql-hive/client"

require "graphql-hive/sampler"
require "graphql-hive/sampling/basic_sampler"
require "graphql-hive/sampling/dynamic_sampler"
require "graphql-hive/schema_reporter"
require "graphql"

module GraphQL
  # GraphQL Hive usage collector and schema reporter
  class Hive < GraphQL::Tracing::PlatformTracing
    @@schema = nil
    @@instance = nil

    DEFAULT_OPTIONS = {
      enabled: true,
      debug: false,
      port: "443",
      collect_usage: true,
      read_operations: true,
      report_schema: true,
      buffer_size: 50,
      queue_size: 1000,
      logger: nil,
      collect_usage_sampling: 1.0
    }.freeze

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
      opts = DEFAULT_OPTIONS.merge(options)
      initialize_options!(opts)
      super(opts)

      @@instance = self

      @client = GraphQL::Hive::Client.new(opts)
      @usage_reporter = GraphQL::Hive::UsageReporter.new(opts, @client)

      send_report_schema if @@schema && opts[:report_schema] && @options[:enabled]
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
      return yield unless @options[:enabled] && @options[:collect_usage]

      if platform_key == "execute_multiplex"
        if data[:multiplex]
          queries = data[:multiplex].queries
          timestamp = (Time.now.utc.to_f * 1000).to_i
          starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          results = yield
          ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          elapsed = ending - starting
          duration = (elapsed.to_f * (10**9)).to_i

          report_usage(timestamp, queries, results, duration) unless queries.empty?
          results
        else
          yield
        end
      else
        yield
      end
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

    def on_start
      @usage_reporter.on_start
    end

    private

    def initialize_options!(options)
      setup_logger(options) if options[:logger].nil?
      return false if missing_token?(options)
      return false if missing_reporting_info?(options)
      true
    end

    private

    def setup_logger(options)
      options[:logger] = Logger.new($stderr)
      original_formatter = Logger::Formatter.new

      options[:logger].formatter = proc { |severity, datetime, progname, msg|
        msg = msg.respond_to?(:dump) ? msg.dump : msg
        original_formatter.call(severity, datetime, progname, "[hive] #{msg}")
      }

      options[:logger].level = options[:debug] ? Logger::DEBUG : Logger::INFO
    end

    def missing_token?(options)
      if !options.include?(:token) && options.dig(:enabled)
        options[:logger].warn("`token` options is missing")
        options[:enabled] = false
        return true
      end
      false
    end

    def missing_reporting_info?(options)
      return false unless options[:report_schema]

      missing_reporting = !options.include?(:reporting)
      missing_author_or_commit = options[:reporting] &&
        (!options[:reporting].include?(:author) || !options[:reporting].include?(:commit))

      if missing_reporting || missing_author_or_commit
        options[:logger].warn("`reporting.author` and `reporting.commit` options are required")
        return true
      end
      false
    end

    def report_usage(timestamp, queries, results, duration)
      @usage_reporter.add_operation([timestamp, queries, results, duration])
    end

    def send_report_schema
      sdl = GraphQL::Schema::Printer.new(@sschema).print_schema
      reporter = SchemaReporter.new(sdl, @client, @options[:reporting])
      reporter.send_report
    end
  end
end
