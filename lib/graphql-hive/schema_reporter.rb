module GraphQLHive
  class SchemaReporter
    REPORT_SCHEMA_MUTATION = <<~MUTATION
      mutation schemaPublish($input: SchemaPublishInput!) {
        schemaPublish(input: $input) {
          __typename
        }
      }
    MUTATION

    def initialize(sdl:, options:)
      @sdl = sdl
      @options = options
      @client = GraphQLHive.configuration.client
    end

    def send_report
      validate_options!
      body = {
        query: REPORT_SCHEMA_MUTATION,
        operationName: "schemaPublish",
        variables: {
          input: {
            sdl: @sdl,
            author: @options[:author],
            commit: @options[:commit],
            service: @options[:service],
            url: @options[:url],
            force: @options[:force]
          }
        }
      }

      @client.send(:"/registry", body, :"report-schema")
    end

    private

    def validate_options!
      raise ArgumentError, "author is required for schema reporting" if @options[:author].nil?
      raise ArgumentError, "commit is required for schema reporting" if @options[:commit].nil?
    end
  end
end
