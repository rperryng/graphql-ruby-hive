# frozen_string_literal: true

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class ThreadManager
      def initialize(options, queue, sampler)
        @options = options
        @buffer = Buffer.new(options, queue, sampler)
        @queue = queue
      end

      def start_thread
        if @thread&.alive?
          @options[:logger].warn("Tried to start operations flushing thread but it was already alive")
          return
        end

        @thread = Thread.new do
          @buffer.run
        rescue => e
          @options[:logger].error(e)
        end
      end

      def join_thread
        @queue.close
        @thread&.join
      end
    end
  end
end
