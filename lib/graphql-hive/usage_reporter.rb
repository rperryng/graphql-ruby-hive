module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class ThreadManager
      def initialize(options, queue, sampler)
        @options = options
        @queue = queue
        @sampler = sampler
        @mutex = Mutex.new
      end

      def start_thread
        if @thread&.alive?
          @options[:logger].warn("Tried to start operations flushing thread but it was already alive")
          return
        end

        @thread = Thread.new do
          buffer = []
          while (operation = @queue.pop(false))
            @options[:logger].debug("processing operation from queue: #{operation}")
            buffer << operation if @sampler.sample?(operation)

            @mutex.synchronize do
              if buffer.size >= @options[:buffer_size]
                @options[:logger].debug("buffer is full, sending!")
                report = Report.new(@options, buffer).to_json
                @client.send(:"/usage", report, :usage)
                buffer = []
              end
            end
          end

          unless buffer.empty?
            @options[:logger].debug("shuting down with buffer, sending!")
            Report.new(@options, @client).process_operations(buffer)
          end
        rescue => e
          @options[:logger].error(e)
        end
      end

      def join_thread
        @queue.close
        @thread.join
      end
    end

    class Report
      def initialize(options, operations)
        @options = options
        @operations = operations
        @report = {
          size: 0,
          map: {},
          operations: []
        }
      end

      def process_operations
        @operations.each do |operation|
          add_operation_to_report(operation)
        end
      end
      alias_method :to_json, :process_operations

      def add_operation_to_report(operation)
        timestamp, queries, results, duration = operation

        errors = errors_from_results(results)

        operation_name = queries.map(&:operations).map(&:keys).flatten.compact.join(", ")
        operation = ""
        fields = Set.new

        queries.each do |query|
          analyzer = GraphQL::Hive::Analyzer.new(query)
          visitor = GraphQL::Analysis::AST::Visitor.new(
            query: query,
            analyzers: [analyzer]
          )

          result = visitor.visit

          fields.merge(analyzer.result)

          operation += "\n" unless operation.empty?
          operation += GraphQL::Hive::Printer.new.print(result)
        end

        md5 = Digest::MD5.new
        md5.update operation
        operation_map_key = md5.hexdigest

        operation_record = {
          operationMapKey: operation_map_key,
          timestamp: timestamp.to_i,
          execution: {
            ok: errors[:errorsTotal].zero?,
            duration: duration,
            errorsTotal: errors[:errorsTotal]
          }
        }

        if results[0]
          context = results[0].query.context
          operation_record[:metadata] = {client: @options[:client_info].call(context)} if @options[:client_info]
        end

        @report[:map][operation_map_key] = {
          fields: fields.to_a,
          operationName: operation_name,
          operation: operation
        }
        @report[:operations] << operation_record
        @report[:size] += 1
      end

      def errors_from_results(results)
        acc = {errorsTotal: 0}
        results.each do |result|
          errors = result.to_h.fetch("errors", [])
          errors.each do
            acc[:errorsTotal] += 1
          end
        end
        acc
      end
    end

    class UsageReporter
      @@instance = nil

      def self.instance
        @@instance
      end

      def initialize(options, client)
        @@instance = self
        @options = options
        @client = client
        @queue = Queue.new
        @sampler = Sampler.new(options[:collect_usage_sampling], options[:logger]) # NOTE: logs for deprecated field
        @thread_manager = ThreadManager.new(options, @queue, @sampler)
        @thread_manager.start_thread
      end

      def add_operation(operation)
        @queue.push(operation)
      end

      def on_exit
        @thread_manager.join_thread
      end

      def on_start
        @thread_manager.start_thread
      end
    end
  end
end
