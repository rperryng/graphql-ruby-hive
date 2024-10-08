# frozen_string_literal: true

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class OperationsBuffer
      def initialize(queue:, sampler:, client:, logger:, options: {})
        @queue = queue
        @sampler = sampler
        @client = client
        @logger = logger
        @max_buffer_size = options[:buffer_size]
        @mutex = Mutex.new
        @buffer = []
        @options = options
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
          report = GraphQL::Hive::Report.new(
            operations: @buffer,
            client_info: @options[:client_info]
          ).to_json
          @client.send(:"/usage", report, :usage)
          @buffer.clear
        end
      end
    end
  end
end
