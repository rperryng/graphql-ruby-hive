module GraphQLHive
  module Trace
    def initialize(multiplex: nil, query: nil, **options)
      @configuration = GraphQLHive.configuration
      @hive = GraphQLHive::Tracing.new(
        usage_reporter: @configuration.usage_reporter
      )
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
  end
end
