# frozen_string_literal: true

module GraphQLHive
  class UsageReporter
    class Error < StandardError; end
    SHUTDOWN_TIMEOUT_SECONDS = 30
    MONITOR_INTERVAL = 1 # seconds

    # Class-level process mutex
    PROCESS_MUTEX = Mutex.new

    def initialize(queue:, logger:, processor:)
      @queue = queue
      @logger = logger
      @processor = processor
      @running = false
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
      PROCESS_MUTEX.synchronize do
        return @logger.warn("Already running") if running?
        return @logger.warn("Another reporter is running in this process") if self.class.reporter_running?

        self.class.mark_reporter_running
        @running = true
        start_processor
        start_monitor
      end
    end
    alias_method :on_start, :start

    def stop
      PROCESS_MUTEX.synchronize do
        return unless @running

        @running = false
        shutdown_threads
        self.class.mark_reporter_stopped
      end
    end
    alias_method :on_exit, :stop

    private

    # Class-level process-wide state management
    class << self
      def reporter_running?
        @global_running ||= false
      end

      def mark_reporter_running
        @global_running = true
      end

      def mark_reporter_stopped
        @global_running = false
      end
    end

    def running?
      @running && @processor_thread&.alive?
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

        while @running
          sleep MONITOR_INTERVAL
          PROCESS_MUTEX.synchronize do
            if @running && !@processor_thread&.alive?
              @logger.warn("Processor died, restarting...")
              start_processor
            end
          end
        end
      rescue => e
        @logger.error("Monitor failed: #{e.message}")
      end
    end

    def shutdown_threads
      @logger.info("Shutting down...")
      @queue.close

      unless @monitor_thread&.join(1)
        @logger.error("Force stopping monitor thread")
        @monitor_thread.kill
      end

      unless @processor_thread.join(SHUTDOWN_TIMEOUT_SECONDS)
        @logger.error("Force stopping processor thread")
        @processor_thread.kill
      end

      @logger.info("Shutdown complete")
    end
  end
end
