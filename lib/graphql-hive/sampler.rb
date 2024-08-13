# frozen_string_literal: true

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    # Sampler instance for usage reporter
    class Sampler
      def initialize(options)
        if options[:collect_usage_sampler]
          @sampler = Sampling::DynamicSampler.new(
            options[:collect_usage_sampler],
            options[:at_least_once_sampling]
          )
        else
          options[:logger].warn('`collect_usage_sampling` is deprecated, use `collect_usage_sampling_rate` instead') if options&.[](:collect_usage_sampling) # rubocop:disable Layout/LineLength
          @sampler = Sampling::BasicSampler.new(
            options[:collect_usage_sampling_rate] || options[:collect_usage_sampling],
            options[:at_least_once_sampling]
          )
        end
      end

      def sample?(operation)
        @sampler.sample?(operation)
      end
    end
  end
end
