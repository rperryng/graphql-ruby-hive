# frozen_string_literal: true

require "graphql-hive/sampling/sampling_context"

module GraphQLHive
  module Sampling
    # Basic sampling for operations reporting
    class BasicSampler
      include GraphQLHive::Sampling::SamplingContext

      def initialize(options:)
        @sample_rate = options[:sample_rate] ? options[:sample_rate].to_f : 1
        @at_least_once = options[:at_least_once]
        @key_generator = options[:key_generator] || DEFAULT_SAMPLE_KEY

        @tracked_operations = {}
      end

      def sample?(operation)
        return SecureRandom.random_number <= @sample_rate if !@at_least_once

        sample_context = get_sample_context(operation)
        operation_key = @key_generator.call(sample_context)

        return false if @tracked_operations.key?(operation_key)

        @tracked_operations[operation_key] = true
        true
      end
    end
  end
end
