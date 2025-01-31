# frozen_string_literal: true

module GraphQLHive
  class Processor
    def initialize(buffer_size:, client:, sampler:, queue:, logger:, client_info: nil)
      @buffer_size = buffer_size
      @client = client
      @sampler = sampler
      @queue = queue
      @logger = logger
      @buffer = []
    end

    def process_queue
      while (op = @queue.pop(false))
        # TODO use data class for operation
        operation = op.deconstruct
        begin
          @logger.debug { "Processing operation from queue: #{operation}" }
          @buffer << operation if @sampler.sample?(operation)

          if @buffer.size >= @buffer_size
            @logger.debug { "Buffer is full, sending report" }
            flush_buffer
          end
        rescue => e
          @buffer.clear
          @logger.error(e)
        end
      end

      flush_buffer unless @buffer.empty?
    end

    def flush_buffer
      report = Report.new(operations: @buffer).build
      @client.send(:"/usage", report, :usage)
      @buffer.clear
    end
  end
end
