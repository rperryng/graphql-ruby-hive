# frozen_string_literal: true

require "digest"
require "graphql-hive/analyzer"
require "graphql-hive/printer"

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class UsageReporter
      def initialize(buffer_size:, client:, sampler:, queue:, logger:, client_info: nil)
        @buffer_size = buffer_size
        @client = client
        @sampler = sampler
        @queue = queue
        @logger = logger
        start
      end

      def add_operation(operation)
        @queue.push(operation, true)
      rescue ThreadError
        @logger.error("SizedQueue is full, discarding operation. Size: #{@queue.size}, Max: #{@queue.max}")
      end

      def start
        if @thread&.alive?
          @logger.warn("Usage reporter is already running")
        end

        @thread = Thread.new do
          process_queue
        rescue => e
          @logger.error(e)
        end
      end
      alias_method :on_start, :start

      def stop
        @queue.close
        @thread&.join
      end
      alias_method :on_exit, :stop

      private

      def process_queue
        buffer = []
        while (operation = @queue.pop(false))
          begin
            @logger.debug("processing operation from queue: #{operation}")
            buffer << operation if @sampler.sample?(operation)

            if buffer.size >= @buffer_size
              @logger.debug("buffer is full, sending!")
              flush_buffer(buffer)
              buffer = []
            end
          rescue => e
            buffer = []
            @logger.error(e)
          end
        end

        flush_buffer(buffer) unless buffer.empty?
      end

      def flush_buffer(buffer)
        report = Report.new(operations: buffer).build
        @logger.debug("sending report: #{report}")
        @client.send(:"/usage", report, :usage)
      end
    end
  end
end
