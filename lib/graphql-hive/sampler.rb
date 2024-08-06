module GraphQL
  class Sampler
    @sample_rate = 1
    @sampler = nil
    @tracked_operations = nil 

    def initialize(client_sampler)
      if (client_sampler.is_a?(Proc))
        @sampler = client_sampler
        @tracked_operations = Hash.new
      elsif (client_sampler.is_a?(Integer))
        @sample_rate = client_sampler
      end
    end

    def should_include(operation)
      if (@sampler)
        if (@tracked_operations.has_key?(operation))
          @sample_rate = @sampler.call(operation)
        else
          @tracked_operations[operation] = true
          @sample_rate = 1
        end
      end

      rand(100) <= @sample_rate
    end
  end
end