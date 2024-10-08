# frozen_string_literal: true

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class ReportingThread
      def initialize(buffer:, logger:)
        @buffer = buffer
        @logger = logger
      end

      def start_thread
        if @thread&.alive?
          @logger.warn("Tried to start operations flushing thread but it was already alive")
          return
        end

        @thread = Thread.new do
          @buffer.run
        rescue => e
          @logger.error(e)
        end
      end

      def join_thread
        @thread&.join
      end
    end
  end
end
