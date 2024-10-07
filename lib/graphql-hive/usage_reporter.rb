# frozen_string_literal: true

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class UsageReporter
      @@instance = nil

      def self.instance
        @@instance
      end

      def initialize(options, client)
        @@instance = self
        @options = options
        @client = client
        @queue = Queue.new
        @sampler = Sampler.new(
          options[:collect_usage_sampling],
          options[:logger]
        )
        @thread_manager = ThreadManager.new(
          options,
          @queue,
          @sampler
        )
        @thread_manager.start_thread
      end

      def add_operation(operation)
        @queue.push(operation)
      end

      def on_exit
        @thread_manager.join_thread
      end

      def on_start
        @thread_manager.start_thread
      end
    end
  end
end
