module GraphQLHive
  module Trace
    def initialize(multiplex: nil, query: nil, **options)
      @configuration = GraphQLHive.configuration
      @hive = GraphQLHive::Tracing.new(
        usage_reporter: @configuration.usage_reporter
      )
      # TODO put in configuration so we don't call this on every trace
      report_schema_to_hive(@configuration.schema)
      super
    end

    def execute_multiplex(multiplex:)
      return super unless _should_collect_usage?

      @hive.trace(queries: multiplex.queries) { super }
    end

    private

    def _should_collect_usage?
      @configuration.enabled? && @configuration.collect_usage?
    end

    def report_schema_to_hive(schema)
      return if schema.nil? || !@configuration.report_schema

      sdl = GraphQL::Schema::Printer.new(schema).print_schema
      SchemaReporter.new(sdl, @configuration.client, @options.reporting).send_report
    end
  end
end
