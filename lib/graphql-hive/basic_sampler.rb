module GraphQL
  class Hive
    # Basic sampling for operations reporting
    class BasicSampler
      def initialize(client_sample_rate)
        if (client_sample_rate.is_a?(Numeric))
          @sample_rate = client_sample_rate
        else
          @sample_rate = 1
        end
      end

      def sample?(operation)
        SecureRandom.random_number <= @sample_rate
      end
    end
  end
end