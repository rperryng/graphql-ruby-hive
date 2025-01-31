module GraphQLHive
  class Tracing
    def initialize(usage_reporter:)
      @usage_reporter = usage_reporter
    end

    def trace(queries:)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      all_results = yield
      elapsed_ns = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1e9).to_i

      @usage_reporter.add_operation(
        GraphQLHive::Operation.new(
          Time.now.to_i * 1000,
          queries,
          all_results.map(&:to_h),
          elapsed_ns
        )
      )

      all_results
    end
  end
end
