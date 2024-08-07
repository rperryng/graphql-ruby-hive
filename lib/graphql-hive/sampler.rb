module GraphQL
  class Hive
    # Dynamic sampler for operations reporting
    class Sampler
      def initialize(client_sampler, operation_key_generator = nil)
        if (client_sampler.is_a?(Proc))
          @sampler = client_sampler
          @tracked_operations = Hash.new
          @operation_key_generator = operation_key_generator
        elsif (client_sampler.is_a?(Numeric))
          @sample_rate = client_sampler
        else
          @sample_rate = 1
        end
      end

      def should_include(operation)
        if (@sampler)
          raise StandardError, "Sampler must return a number" unless (@sampler.call(operation).is_a?(Numeric))

          operation_key = @operation_key_generator ? @operation_key_generator.call(operation).to_s : operation

          if (@tracked_operations.has_key?(operation_key))
            @sample_rate = @sampler.call(operation) # TODO: determine necessary arguments
          else
            @tracked_operations[operation_key] = true 
            return true
          end
        end

        rand(0.0..1.0) <= @sample_rate
      end
    end
  end
end