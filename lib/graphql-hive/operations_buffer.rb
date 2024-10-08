# frozen_string_literal: true

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class OperationsBuffer
      def initialize(options, queue, sampler)
        @buffer = []
        @max_buffer_size = options[:buffer_size]
        @mutex = Mutex.new
        @options = options
        @queue = queue
        @sampler = sampler
        @client = GraphQL::Hive::Client.new(options)
        @logger = GraphQL::Hive.instance.logger
      end

      def run
        while (operation = @queue.pop(false))
          @logger.debug("processing operation from queue: #{operation}")
          @buffer << operation if @sampler.sample?(operation)
          flush_buffer if full?
        end
      end

      private

      def full?
        @buffer.size >= @max_buffer_size
      end

      def flush_buffer
        @mutex.synchronize do
          @logger.debug("Buffer is full, sending report.")
          puts "Buffer is full, sending report."
          report = GraphQL::Hive::Report.new(@options, @buffer).to_json
          @client.send(:"/usage", report, :usage)
          @buffer.clear
        end
      end
    end
  end
end
