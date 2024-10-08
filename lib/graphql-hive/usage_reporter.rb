# frozen_string_literal: true

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class UsageReporter
      @@instance = nil

      def self.instance
        @@instance
      end

      def initialize(reporting_thread:, queue:, logger:)
        @@instance = self
        @reporting_thread = reporting_thread
        @queue = queue
        @logger = logger
      end

      def add_operation(operation)
        @queue.push(operation)
      end

      def on_exit
        @logger.debug("Shutting down usage reporter")
        @queue.close
        @reporting_thread.join_thread
      end

      def on_start
        @logger.debug("Starting usage reporter")
        @reporting_thread.start_thread
      end
    end
  end
end
