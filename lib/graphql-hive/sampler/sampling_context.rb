module GraphQL
  class Hive
    module Sampler
      module SamplingContext
        private

        def get_sample_context(operation) 
          _, queries, results, _ = operation

          operation_name = queries.map(&:operations).map(&:keys).flatten.compact.join(', ')

          parsed_definitions = []
          queries.each do |query|
            parsed_query = GraphQL::Language::Parser.parse(query.query_string)
            parsed_definitions.concat(parsed_query.definitions)
          end
          document = GraphQL::Language::Nodes::Document.new(definitions: parsed_definitions)

          context_value = results[0].query.context

          {
            operation_name: operation_name,
            document: document,
            context_value: context_value
          }
        end

        def get_sample_rate(sample_context)
          sample_rate = @sampler.call(sample_context)
          raise StandardError, "Sampler must return a number" unless (sample_rate.is_a?(Numeric))
          sample_rate
        rescue => e
          raise StandardError, "Error calling sampler: #{e}"
        end

        def get_sample_key(sample_context)
          return default_sample_key.call(sample_context) if @at_least_once_sampling_keygen == "default"
          @at_least_once_sampling_keygen.call(sample_context).to_s
        rescue => e
          raise StandardError, "Error getting key for sample: #{e}"
        end

        def default_sample_key
          Proc.new { |sample_context| sample_context[:operation_name] + sample_context[:document].to_query_string }
        end
      end
    end
  end
end