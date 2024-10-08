# frozen_string_literal: true

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class UsageReporter
      @@instance = nil

      def self.instance
        @@instance
      end

      def initialize(options:, logger:)
        @@instance = self
        @logger = logger
        @queue = Queue.new
        sampler = GraphQL::Hive::Sampler.new(
          options[:collect_usage_sampling],
          logger
        )
        client = GraphQL::Hive::Client.new(
          token: options[:token],
          port: options[:port],
          endpoint: options[:endpoint],
          logger: logger
        )
        buffer = GraphQL::Hive::OperationsBuffer.new(
          queue: @queue,
          sampler: sampler,
          client: client,
          options: options,
          logger: logger
        )
        @reporting_thread = GraphQL::Hive::ReportingThread.new(
          queue: @queue,
          buffer: buffer,
          logger: logger
        )
      end

      def add_operation(operation)
        @queue.push(operation)
      end

      def on_exit
        @logger.debug("Shutting down usage reporter")
        @reporting_thread.join_thread
      end

      def on_start
        @logger.debug("Starting usage reporter")
        @reporting_thread.start_thread
      end
    end
  end
end
