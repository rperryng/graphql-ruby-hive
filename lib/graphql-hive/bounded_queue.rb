module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class BoundedQueue < Thread::Queue
      def initialize(size:, logger:)
        @size = size
        @logger = logger

        super()
      end

      def push(item)
        # call size on the instance of this queue
        if size >= @size
          @logger.error("BoundedQueue is full, discarding operation")
          return
        end

        super(item)
      end
    end
  end
end
