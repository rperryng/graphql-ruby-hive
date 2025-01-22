# frozen_string_literal: true

require "concurrent/atomic/atomic_boolean"

module GraphQLHive
  class UsageReporter
    class Error < StandardError; end
    SHUTDOWN_TIMEOUT_SECONDS = 30

    def initialize(queue:, logger:, processor:)
      @queue = queue
      @logger = logger
      @processor = processor
      @running = Concurrent::AtomicBoolean.new(false)
      @lock = Mutex.new
    end

    def add_operation(operation)
      return @logger.warn("Queue closed, discarding operation") if @queue.closed?
      @queue.push(operation, true)
    rescue ThreadError
      @logger.error("Queue full (size: #{@queue.size}/#{@queue.max}), discarding operation")
    rescue ClosedQueueError
      # Queue was closed while pushing - normal during shutdown
    end

    def start
      # Only ever start one instance of the usage reporter
      @lock.synchronize do
        return @logger.warn("Already running") if running?

        @running.make_true
        start_processor
        start_monitor
      end
    end
    alias_method :on_start, :start

    def stop
      @lock.synchronize do
        return unless @running.true?

        @running.make_false
        shutdown_threads
      end
    end
    alias_method :on_exit, :stop

    private

    def running?
      @running.true? && @processor_thread&.alive?
    end

    def start_processor
      @processor_thread = Thread.new do
        Thread.current.name = "graphql_hive_processor"
        Thread.current.abort_on_exception = true

        @processor.process_queue
      rescue => e
        @logger.error("Processor failed: #{e.message}")
        raise Error, "Processor failed: #{e.message}"
      end
    end

    def start_monitor
      @monitor_thread = Thread.new do
        Thread.current.name = "graphql_hive_monitor"
        Thread.current.abort_on_exception = true

        monitor_processor_health
      rescue => e
        @logger.error("Monitor failed: #{e.message}")
      end
    end

    def monitor_processor_health
      while @running.true?
        @lock.synchronize do
          if @running.true? && !@processor_thread&.alive?
            @logger.warn("Processor died, restarting...")
            start_processor
          end
        end
        sleep 1
      end
    end

    def shutdown_threads
      @logger.info("Shutting down...")
      @queue.close

      unless @processor_thread.join(SHUTDOWN_TIMEOUT_SECONDS)
        @logger.error("Force stopping processor thread")
        @processor_thread.kill
      end

      @monitor_thread&.kill
      @logger.info("Shutdown complete")
    end
  end
end
