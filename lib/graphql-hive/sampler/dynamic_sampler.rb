require 'graphql-hive/sampler/sampling_context'

module GraphQL
  class Hive
    module Sampler
      # Dynamic sampling for operations reporting
      class DynamicSampler
        include GraphQL::Hive::Sampler::SamplingContext

        def initialize(client_sampler, at_least_once_sampling_keygen = nil)
          @sampler = client_sampler
          @tracked_operations = Hash.new
          @at_least_once_sampling_keygen = at_least_once_sampling_keygen
        end

        def sample?(operation)
          sample_context = get_sample_context(operation)

          if (@at_least_once_sampling_keygen)
            operation_key = get_sample_key(sample_context)
            unless(@tracked_operations.has_key?(operation_key))
              @tracked_operations[operation_key] = true 
              return true
            end
          end

          sample_rate = get_sample_rate(sample_context)
          SecureRandom.random_number <= sample_rate
        end
      end
    end
  end
end