# frozen_string_literal: true

require "graphql-hive/sampling/sampling_context"

module GraphQLHive
  module Sampling
    # Dynamic sampling for operations reporting
    class DynamicSampler
      include GraphQLHive::Sampling::SamplingContext

      def initialize(options: {})
        @sampler = options[:sampler]
        @at_least_once = options[:at_least_once]
        @key_generator = options[:key_generator] || DEFAULT_SAMPLE_KEY
        @tracked_operations = {}
      end

      def sample?(operation)
        sample_context = get_sample_context(operation)
        return SecureRandom.random_number <= @sampler.call(sample_context) if !@at_least_once

        operation_key = @key_generator.call(sample_context)
        return false if @tracked_operations.key?(operation_key)

        @tracked_operations[operation_key] = true
        true
      end
    end
  end
end
