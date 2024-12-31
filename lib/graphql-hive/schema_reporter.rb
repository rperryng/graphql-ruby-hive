class GraphQL::Hive::SchemaReporter
  REPORT_SCHEMA_MUTATION = <<~MUTATION
    mutation schemaPublish($input: SchemaPublishInput!) {
      schemaPublish(input: $input) {
        __typename
      }
    }
  MUTATION

  def initialize(sdl, client, reporting_options)
    @sdl = sdl
    @client = client
    @reporting_options = reporting_options
  end

  def send_report
    body = {
      query: REPORT_SCHEMA_MUTATION,
      operationName: "schemaPublish",
      variables: {
        input: {
          sdl: @sdl,
          author: @reporting_options[:author],
          commit: @reporting_options[:commit],
          service: @reporting_options[:service_name],
          url: @reporting_options[:service_url],
          force: true
        }
      }
    }

    @client.send(:"/registry", body, :"report-schema")
  end
end
