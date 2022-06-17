require 'digest'
require "net/http"
require "uri"
require 'logger'


require "graphql-hive/version"
require "graphql-hive/analyzer"
require "graphql-hive/printer"



# class MySchema < GraphQL::Schema
#   use(
#     GraphQL::Hive,
#     {
#       token: 'YOUR-TOKEN',
#       collect_usage: true,
#       report_schema: true,
#       enabled: true, // Enable/Disable Hive Client
#       debug: true, // Debugging mode
#       logger: MyLogger.new,
#       reporting: {
#         author: 'Author of the latest change',
#         commit: 'git sha or any identifier',
#         service_name: '',
#         service_url: '',
#       },
#     }
#   )
#
#   # ...
#
# end

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing

    @@schema = nil

    REPORT_SCHEMA_MUTATION = <<-MUTATION
mutation schemaPublish($input: SchemaPublishInput!) {
  schemaPublish(input: $input) {
    __typename
  }
}
MUTATION

    DEFAULT_OPTIONS = {
      enabled: true,
      collect_usage: true,
      read_operations: true,
      report_schema: true,
      buffer_size: 50,
      logger: Logger.new(STDOUT),
    }

    self.platform_keys = {
      'lex' => 'lex',
      'parse' => 'parse',
      'validate' => 'validate',
      'analyze_query' => 'analyze_query',
      'analyze_multiplex' => 'analyze_multiplex',
      'execute_multiplex' => 'execute_multiplex',
      'execute_query' => 'execute_query',
      'execute_query_lazy' => 'execute_query_lazy'
    }

    def initialize(options = {})
      opts = DEFAULT_OPTIONS.merge(options)
      validate_options!(opts)
      super(opts)

      # buffer
      @report = {
        size: 0,
        map: {},
        operations: [],
      }

      send_report_schema(@@schema) if @@schema && opts[:report_schema] && @options[:enabled]
    end

    def self.use(schema, **kwargs)
      @@schema = schema
      super
    end

    # called on trace events
    def platform_trace(platform_key, _key, data)
      return yield unless @options[:enabled] && @options[:collect_usage]

      if platform_key == 'execute_multiplex'
        if data[:multiplex]
          queries = data[:multiplex].queries
          timestamp = Time.now.utc
          starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          results = yield
          ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          elapsed = ending - starting
          duration = (elapsed.to_f * (10 ** 9)).to_i

          add_operation_to_report(timestamp, queries, results, duration) unless queries.empty?
          
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

    private

    def validate_options!(options)
      puts options
      if !options.include?(:token) && (!options.include?(:enabled) || options.enabled)
        log(:client, "`token` options is missing", :warn)
        options[:enabled] = false
        false
      elsif options[:report_schema] && (!options.include?(:reporting) || (options.include?(:reporting) && (!options[:reporting].include?(:author) || !options[:reporting].include?(:commit))))
        log_report_schema('`reporting.author` and `reporting.commit` options are required', :warn)
        false
      end
      true
    end

    def add_operation_to_report(timestamp, queries, results, duration)
      errors = errors_from_results(results)

      operation_name = queries.map(&:operations).map(&:keys).flatten.compact.join(', ')
      operation = ''
      fields = Set.new

      queries.each do |query|
        analyzer = GraphQL::Hive::Analyzer.new(query)
        visitor = GraphQL::Analysis::AST::Visitor.new(
          query: query,
          analyzers: [analyzer]
        )

        visitor.visit

        fields.merge(analyzer.result)

        operation += "\n" unless operation.empty?
        operation += GraphQL::Hive::Printer.new.print(visitor.result)
      end

      md5 = Digest::MD5.new
      md5.update operation
      operation_map_key = md5.hexdigest

      operation_record = {
        operationMapKey: operation_map_key,
        timestamp: timestamp.to_i,
        execution: {
          ok: errors[:errorsTotal] == 0,
          duration: duration,
          errorsTotal: errors[:errorsTotal],
          errors: errors[:errors],
        }
      }
      
      @report[:map][operation_map_key] = {
        fields: fields,
        operationName: operation_name,
        operation: operation
      }
      @report[:operations] << operation_record
      @report[:size] += 1

      log_usage(JSON.generate(@report).inspect, :debug)

      send_usage_report # if @report.size > @options.buffer_size
    end

    def send_usage_report
      return unless @report.size > 0

      send('/usage', @report, :usage)
    end

    def send_report_schema(schema)
      log_report_schema(schema.inspect)
      sdl = GraphQL::Schema::Printer.new(schema).print_schema
      
      log_report_schema("sdl: #{sdl}")

      body = {
        query: REPORT_SCHEMA_MUTATION,
        operationName: 'schemaPublish',
        variables: {
          input: {
            sdl: sdl,
            author: @options[:reporting][:author],
            commit: @options[:reporting][:commit],
            service: @options[:reporting][:service_name],
            url: @options[:reporting][:service_url],
            force: true,
          },
        }
      }

      log_report_schema(JSON.generate(body).inspect, :debug)

      send('/registry', body, :'report-schema')
    end

    def send(path, body, log_type)
      begin
        uri =
          URI::HTTP.build(
            scheme: "https",
            host: 'app.staging.graphql-hive.com',
            port: "443",
            path: path
          )

        http = ::Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 2
        request = Net::HTTP::Post.new(uri.request_uri)
        request['content-type'] = 'application/json'
        request['x-api-token'] = @options[:token]
        request['User-Agent'] = "Hive@#{Graphql::Hive::VERSION}"
        request['graphql-client-name'] = 'Hive Client'
        request['graphql-client-version'] = Graphql::Hive::VERSION
        request.body = JSON.generate(body)
        response =  http.request(request)

        log(log_type, response.inspect, :debug)
        log(log_type, response.body.inspect, :debug)
      rescue StandardError => e
        log(log_type, "Failed to send data: #{e}", :fatal)
      end
    end

    def log_usage(msg, level = :info)
      log(:usage, msg, level)
    end

    def log_report_schema(msg, level = :info)
      log(:'report-schema', msg, level)
    end

    def log(type, msg, level = :info)
      @options[:logger].send(level, "[hive][#{type}] #{msg}") unless level == :debug && !@options[:debug]
    end

    ###################
    # Operation parsing
    ###################

    def errors_from_results(results)
      acc = { errorsTotal: 0, errors: [] }
      results.each do |result|
        errors = result.to_h.fetch("errors", [])
        errors.each do |error|
          acc[:errorsTotal] += 1
          acc[:errors] << { message: error['message'], path: error['path'].join('.') }
        end
      end
      acc
    end

  end
end
