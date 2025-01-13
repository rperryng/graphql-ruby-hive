module GraphQLHive
  class Tracing
    include Singleton

    attr_accessor :configuration

    Operation = Data.define(:timestamp, :queries, :results, :elapsed_ns)

    def initialize
      @usage_reporter = nil
    end

    def trace(queries:)
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
