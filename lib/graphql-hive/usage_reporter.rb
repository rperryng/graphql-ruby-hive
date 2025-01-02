# frozen_string_literal: true

require "digest"
require "graphql-hive/analyzer"
require "graphql-hive/printer"

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    # Report usage to Hive API without impacting application performances
    class UsageReporter
      @@instance = nil

      def self.instance
        @@instance
      end

      def initialize(options, client)
        @@instance = self
        @options = options
        @client = client
        @options_mutex = Mutex.new
        @sampler = Sampler.new(options.collect_usage_sampling, options.logger) # NOTE: logs for deprecated field
        @queue = Thread::SizedQueue.new(options.queue_size)

        start_thread
      end

      def add_operation(operation)
        @queue.push(operation, true)
      rescue ThreadError
        @options.logger.error("SizedQueue is full, discarding operation. Size: #{@queue.size}, Max: #{@queue.max}")
      end

      def on_exit
        @queue.close
        @thread.join
      end

      def on_start
        start_thread
      end

      private

      def start_thread
        if @thread&.alive?
          @options.logger.warn("Tried to start operations flushing thread but it was already alive")
          return
        end

        @thread = Thread.new do
          buffer = []
          while (operation = @queue.pop(false))
            begin
              @options.logger.debug("processing operation from queue: #{operation}")
              buffer << operation if @sampler.sample?(operation)

              @options_mutex.synchronize do
                if buffer.size >= @options.buffer_size
                  @options.logger.debug("buffer is full, sending!")
                  process_operations(buffer)
                  buffer = []
                end
              end
            rescue => e
              buffer = []
              @options.logger.error(e)
            end
          end

          unless buffer.empty?
            @options.logger.debug("shuting down with buffer, sending!")
            process_operations(buffer)
          end
        rescue => e
          # ensure configured logger receives exception as well in setups where STDERR might not be
          # monitored.
          @options.logger.error(e)
        end
      end

      def process_operations(operations)
        report = {
          size: 0,
          map: {},
          operations: []
        }

        operations.each do |operation|
          add_operation_to_report(report, operation)
        end

        @options.logger.debug("sending report: #{report}")

        @client.send(:"/usage", report, :usage)
      end

      def add_operation_to_report(report, operation)
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
          operation_record[:metadata] = {client: @options.client_info.call(context)} if @options.client_info
        end

        report[:map][operation_map_key] = {
          fields: fields.to_a,
          operationName: operation_name,
          operation: operation
        }
        report[:operations] << operation_record
        report[:size] += 1
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
  end
end
