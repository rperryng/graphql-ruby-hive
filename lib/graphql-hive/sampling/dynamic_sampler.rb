# frozen_string_literal: true

require 'graphql-hive/sampling/sampling_context'

module GraphQL
  class Hive
    module Sampling
      # Dynamic sampling for operations reporting
      class DynamicSampler
        include GraphQL::Hive::Sampling::SamplingContext

        def initialize(client_sampler, at_least_once, key_generator)
          @sampler = client_sampler
          @tracked_operations = {}
          @key_generator = key_generator || DEFAULT_SAMPLE_KEY if at_least_once
        end

        def sample?(operation)
          sample_context = get_sample_context(operation)

          if @key_generator
            operation_key = @key_generator.call(sample_context)
            unless @tracked_operations.key?(operation_key)
              @tracked_operations[operation_key] = true
              return true
            end
          end

          SecureRandom.random_number <= @sampler.call(sample_context)
        end
      end
    end
  end
end
