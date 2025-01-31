# frozen_string_literal: true

require "digest"
require "graphql-hive/analyzer"
require "graphql-hive/printer"
require "graphql-hive/processor"

module GraphQLHive
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
      @logger.warn do
        "SizedQueue is full, discarding operation. Size: #{@queue.size}, Max: #{@queue.max}"
      end
    end

    def start
      if @thread&.alive?
        @logger.warn { "Usage reporter is already running" }
      end

      # TODO consider using Fibers instead of threads because they are lighter weight
      # and this work is not CPU intensive.
      @thread = Thread.new do
        Processor.new(
          buffer_size: @buffer_size,
          client: @client,
          sampler: @sampler,
          queue: @queue,
          logger: @logger
        ).process_queue
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
  end
end
