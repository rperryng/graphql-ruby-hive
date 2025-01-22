# frozen_string_literal: true

require "digest"
require "graphql-hive/analyzer"
require "graphql-hive/printer"
require "graphql-hive/processor"

module GraphQLHive
  class UsageReporter
    class Error < StandardError; end

    def initialize(buffer_size:, client:, sampler:, queue:, logger:, client_info: nil)
      @buffer_size = buffer_size
      @client = client
      @sampler = sampler
      @queue = queue
      @logger = logger
      @mutex = Mutex.new
      @stopping = false
    end

    def add_operation(operation)
      return if @stopping
      @queue.push(operation, true)
    rescue ThreadError
      @logger.error("SizedQueue is full, discarding operation. Size: #{@queue.size}, Max: #{@queue.max}")
    rescue ClosedQueueError
      @logger.error("Queue is closed, discarding operation")
    end

    def start
      @mutex.synchronize do
        if @thread&.alive?
          @logger.warn("Usage reporter is already running")
          return
        end

        @stopping = false
        create_processing_thread
        create_monitoring_thread
      end
    end
    alias_method :on_start, :start

    def stop
      @mutex.synchronize do
        return unless @thread&.alive? || @monitor_thread&.alive?

        @stopping = true
        @logger.info("Stopping usage reporter...")

        # Stop monitoring first
        @monitor_thread&.kill
        @monitor_thread = nil

        # Allow time for current operations to process
        @queue.close

        # Wait for thread with timeout
        unless @thread.join(30) # 30 second timeout
          @logger.error("Usage reporter thread failed to stop gracefully")
          @thread.kill
        end

        @thread = nil
        @logger.info("Usage reporter stopped")
      end
    end
    alias_method :on_exit, :stop

    private

    def create_monitoring_thread
      @monitor_thread = Thread.new do
        setup_monitor_thread
        monitor_processing_thread
      rescue => e
        log_monitor_thread_error(e)
      end
    end

    def setup_monitor_thread
      Thread.current.name = "graphql_hive_monitor"
      Thread.current.abort_on_exception = true
    end

    def monitor_processing_thread
      retry_count = 0
      max_retries = 3

      until @stopping
        if processing_thread_alive?(retry_count)
          retry_count = 0
        else
          break if max_retries_reached?(retry_count, max_retries)
          restart_processing_thread(retry_count, max_retries)
          retry_count += 1
        end
        sleep 1
      end
    end

    def processing_thread_alive?(retry_count)
      return false unless @thread&.alive?

      # Reset retry count if thread stays alive for 5+ minutes
      retry_count > 0 && (Time.now - @thread[:started_at]) > 300
    end

    def max_retries_reached?(retry_count, max_retries)
      return false unless retry_count >= max_retries

      @logger.error("Processing thread died #{retry_count} times, giving up")
      @stopping = true
      true
    end

    def restart_processing_thread(retry_count, max_retries)
      @logger.warn("Processing thread died, restarting... (attempt #{retry_count + 1}/#{max_retries})")
      create_processing_thread
    end

    def log_monitor_thread_error(error)
      @logger.error("Monitor thread died: #{error.class} - #{error.message}")
      @logger.error(error.backtrace.join("\n"))
    end

    def create_processing_thread
      @thread = Thread.new do
        Thread.current[:started_at] = Time.now
        Thread.current.name = "graphql_hive_reporter"
        Thread.current.abort_on_exception = true

        begin
          processor = Processor.new(
            buffer_size: @buffer_size,
            client: @client,
            sampler: @sampler,
            queue: @queue,
            logger: @logger
          )
          processor.process_queue
        rescue => e
          @logger.error("Usage reporter thread died: #{e.class} - #{e.message}")
          @logger.error(e.backtrace.join("\n"))
          raise Error, "Usage reporter failed: #{e.message}"
        ensure
          @logger.info("Usage reporter thread finishing")
        end
      end
    end
  end
end
