module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    # BoundedQueue is being used so that the queue does not grow indefinitely
    # We do not use `SizedQueue` because it blocks the thread when the queue is full with a .wait call
    # This would go against us not impacting the application performance with the usage reporter
    class BoundedQueue < Thread::Queue
      def initialize(bound:, logger:)
        @bound = bound
        @logger = logger
        @lock = Mutex.new

        super()
      end

      def push(item)
        @lock.synchronize do
          if size >= @bound
            @logger.error("BoundedQueue is full, discarding operation")
            return
          end
          super
        end
      end
    end
  end
end
