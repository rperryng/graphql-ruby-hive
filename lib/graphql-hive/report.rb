module GraphQLHive
  class Report
    attr_reader :body
    def initialize(operations:, client_info: nil)
      @client_info = client_info
      @operations = operations
    end

    def build
      @body ||= @operations.each_with_object(initialize_report) do |operation, report|
        timestamp, queries, results, duration = operation
        errors = errors_from_results(results)
        operation_name = extract_operation_name(queries)
        operation_details = build_operation_details(queries)
        operation_map_key = generate_operation_key(operation_details)

        operation_record = build_operation_record(
          operation_map_key, timestamp, duration, errors, results
        )

        operation, fields = operation_details

        report[:map][operation_map_key] = {
          fields: fields.to_a,
          operationName: operation_name,
          operation: operation
        }
        report[:operations] << operation_record
        report[:size] += 1
      end
    end

    private

    def initialize_report
      {
        size: 0,
        map: {},
        operations: []
      }
    end

    def extract_operation_name(queries)
      queries.map(&:operations).map(&:keys).flatten.compact.join(", ")
    end

    def build_operation_details(queries)
      operation = ""
      fields = Set.new

      queries.each do |query|
        analyzer = GraphQLHive::Analyzer.new(query)
        visitor = GraphQL::Analysis::AST::Visitor.new(
          query: query,
          analyzers: [analyzer]
        )

        result = visitor.visit
        fields.merge(analyzer.result)

        operation += "\n" unless operation.empty?
        operation += GraphQLHive::Printer.new.print(result)
      end

      [operation, fields]
    end

    def generate_operation_key(operation_details)
      operation, = operation_details
      Digest::MD5.hexdigest(operation)
    end

    def build_operation_record(operation_map_key, timestamp, duration, errors, results)
      record = {
        operationMapKey: operation_map_key,
        timestamp: timestamp.to_i,
        execution: {
          ok: errors[:errorsTotal].zero?,
          duration: duration,
          errorsTotal: errors[:errorsTotal]
        }
      }

      if results[0] && @client_info
        context = results[0].query.context
        record[:metadata] = {client: @client_info.call(context)}
      end

      record
    end

    def update_report(report, operation_map_key, operation_name, operation_details, operation_record)
      operation, fields = operation_details

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
