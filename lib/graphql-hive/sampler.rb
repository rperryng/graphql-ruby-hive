module GraphQL
  class Hive
    # Dynamic sampler for operations reporting
    class Sampler
      def initialize(client_sampler, operation_key_generator = nil)
        if (client_sampler.is_a?(Proc))
          @sampler = client_sampler
          @tracked_operations = Hash.new
          @operation_key_generator = operation_key_generator
        elsif (client_sampler.is_a?(Numeric))
          @sample_rate = client_sampler
        else
          @sample_rate = 1
        end
      end

      def should_include(operation)
        if (@sampler)
          sample_context = get_sample_context(operation)

          raise StandardError, "Sampler must return a number" unless (@sampler.call(sample_context).is_a?(Numeric))

          operation_key = @operation_key_generator ? @operation_key_generator.call(sample_context).to_s : operation

          if (@tracked_operations.has_key?(operation_key))
            @sample_rate = @sampler.call(sample_context)
          else
            @tracked_operations[operation_key] = true 
            return true
          end
        end

        rand(0.0..1.0) <= @sample_rate
      end

      private
      def get_sample_context(operation) 
        _, queries, results, _ = operation

        operation_name = queries.map(&:operations).map(&:keys).flatten.compact.join(', ')
        context = results[0].query.context
        document = GraphQL::Language::Nodes::Document.new(definitions: [])
        queries.each do |query|
          parsed_query = GraphQL.parse(query)
          document.definitions.concat(parsed_query.definitions)
        end

        {
          operation_name: operation_name,
          document: document,
          context: context
        }
      end
    end
  end
end