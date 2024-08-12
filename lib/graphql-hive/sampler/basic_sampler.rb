# frozen_string_literal: true

require 'graphql-hive/sampler/sampling_context'

module GraphQL
  class Hive
    module Sampler
      # Basic sampling for operations reporting
      class BasicSampler
        include GraphQL::Hive::Sampler::SamplingContext

        def initialize(client_sample_rate = 1, at_least_once_sampling_keygen = nil)
          @sample_rate = client_sample_rate
          @tracked_operations = {}
          @at_least_once_sampling_keygen = at_least_once_sampling_keygen
        end

        def sample?(operation)
          if @at_least_once_sampling_keygen
            sample_context = get_sample_context(operation)
            operation_key = get_sample_key(@at_least_once_sampling_keygen, sample_context)

            unless @tracked_operations.key?(operation_key)
              @tracked_operations[operation_key] = true
              return true
            end
          end

          SecureRandom.random_number <= @sample_rate
        end
      end
    end
  end
end
