# frozen_string_literal: true

require "graphql-hive/report"

module GraphQLHive
  class Processor
    def initialize(queue:, logger:, sampler:, client:, buffer_size:, client_info: nil)
      @queue = queue
      @logger = logger
      @sampler = sampler
      @client_info = client_info
      @client = client
      @buffer_size = buffer_size
      @buffer = []
    end

    def process_queue
      while process_next_operation
        flush_buffer if buffer_full?
      end

      flush_buffer unless @buffer.empty?
    end

    private

    def process_next_operation
      return false if @queue.closed?

      operation = @queue.pop
      return true if operation.nil? || !@sampler.sample?(operation)

      @buffer << operation
      true
    rescue => e
      @logger.error("Failed to process operation: #{e.message}")
      true
    end

    def buffer_full?
      @buffer.size >= @buffer_size
    end

    def flush_buffer
      @logger.debug("Flushing #{@buffer.size} operations")
      report = Report.new(operations: @buffer, client_info: @client_info).build
      @client.send(:"/usage", report, :usage)
      @buffer.clear
    rescue => e
      @logger.warn("Failed to flush buffer. Dropping #{@buffer.size} operations: #{e.message}")
      @buffer.clear
    end
  end
end
