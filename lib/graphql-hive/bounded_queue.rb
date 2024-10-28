module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class BoundedQueue < Thread::Queue
      def initialize(bound:, logger:)
        @bound = bound
        @logger = logger
        @lock = Mutex.new

        super()
      end

      def push(item)
        # call size on the instance of this queue
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
