# frozen_string_literal: true

module GraphQLHive
  module Sampling
    # Helper methods for sampling
    module SamplingContext
      private

      DEFAULT_SAMPLE_KEY = proc { |sample_context|
        md5 = Digest::MD5.new
        md5.update sample_context[:document].to_query_string
        md5.hexdigest
      }

      def get_sample_context(operation)
        operation_name = operation.queries.map(&:operations).map(&:keys).flatten.compact.join(", ")

        parsed_definitions = []
        operation.queries.each do |query|
          query_document = query.document
          parsed_definitions.concat(query_document.definitions) if query_document
        end
        document = GraphQL::Language::Nodes::Document.new(definitions: parsed_definitions)

        context_value = operation.results[0].query.context

        {
          operation_name: operation_name,
          document: document,
          context_value: context_value
        }
      end
    end
  end
end
