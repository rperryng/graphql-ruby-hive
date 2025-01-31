# frozen_string_literal: true

module GraphQLHive
  class Sampler
    def self.build(options:)
      case options
      when Numeric, String, nil
        Sampling::BasicSampler.new(options: {sample_rate: options})
      when ->(opt) { opt.is_a?(Hash) && opt[:sample_rate].is_a?(Float) }
        Sampling::BasicSampler.new(options: options)
      else
        Sampling::DynamicSampler.new(options: options)
      end
    end
  end
end
