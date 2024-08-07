module GraphQL
  class Hive
    class Sampler
      def initialize(client_sampler)
        if (client_sampler.is_a?(Proc))
          @sampler = client_sampler
          @tracked_operations = Hash.new
        elsif (client_sampler.is_a?(Integer))
          @sample_rate = client_sampler
        else
          @sample_rate = 1
        end
      end

      def should_include(operation)
        if (@sampler)
          if (@tracked_operations.has_key?(operation))
            @sample_rate = @sampler.call(operation) # TODO: determine necessary arguments
            # TODO: implement keyFn
          else
            @tracked_operations[operation] = true
            @sample_rate = 1
          end
        end

        rand(0.0..1.0) <= @sample_rate
      end
    end
  end
end