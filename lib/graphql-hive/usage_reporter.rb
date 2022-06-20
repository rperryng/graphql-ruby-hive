# frozen_string_literal: true

require 'digest'
require 'graphql-hive/analyzer'
require 'graphql-hive/printer'

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    # Report usage to Hive API without impacting application performances
    class UsageReporter
      @@instance = nil

      @queue = nil
      @thread = nil
      @operations_buffer = nil
      @client = nil
      @logger = nil

      def self.instance
        @@instance
      end

      def initialize(options, client)
        @@instance = self

        @buffer_size = options[:buffer_size]
        @logger = options[:logger]
        @client = client
        @operations_buffer = []

        @queue = Queue.new

        @thread = Thread.new do
          while !@queue.empty? || !@queue.closed?
            operations = @queue.pop(false)
            process_operations operations
          end
        end
      end

      def add_operation(operation)
        @logger.debug("add operation to buffer: #{operation}")

        @operations_buffer << operation

        if @operations_buffer.size >= @buffer_size
          @logger.debug("buffer is full, sending!")
          @queue.push @operations_buffer
          @operations_buffer = []
        end
      end


      def on_exit
        @queue.push @operations_buffer unless @operations_buffer.empty?
        @queue.close
        @thread.join
      end

      private

      def process_operations(operations)
        report = {
          size: 0,
          map: {},
          operations: []
        }

        operations.each do |operation|
          add_operation_to_report(report, operation)
        end

        @client.send('/usage', report, :usage)
      end

      def add_operation_to_report(report, operation)
        timestamp, queries, results, duration = operation

        errors = errors_from_results(results)
  
        operation_name = queries.map(&:operations).map(&:keys).flatten.compact.join(', ')
        operation = ''
        fields = Set.new
  
        queries.each do |query|
          analyzer = GraphQL::Hive::Analyzer.new(query)
          visitor = GraphQL::Analysis::AST::Visitor.new(
            query: query,
            analyzers: [analyzer]
          )
  
          visitor.visit
  
          fields.merge(analyzer.result)
  
          operation += "\n" unless operation.empty?
          operation += GraphQL::Hive::Printer.new.print(visitor.result)
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
            errorsTotal: errors[:errorsTotal],
            errors: errors[:errors]
          }
        }
  
        context = results[0].query.context
  
        # TBD
        # operation_record[:metadata] = { client: @options[:client_info].call(context) } if @options[:client_info]
  
        report[:map][operation_map_key] = {
          fields: fields.to_a,
          operationName: operation_name,
          operation: operation
        }
        report[:operations] << operation_record
        report[:size] += 1
      end

      def errors_from_results(results)
        acc = { errorsTotal: 0, errors: [] }
        results.each do |result|
          errors = result.to_h.fetch('errors', [])
          errors.each do |error|
            acc[:errorsTotal] += 1
            acc[:errors] << { message: error['message'], path: error['path'].join('.') }
          end
        end
        acc
      end

    end

  end
end
