RSpec.describe GraphQLHive::SchemaReporter do
  let(:sdl) { "type Query { hello: String }" }
  let(:client) { instance_double("GraphQLHive::Client") }
  let(:reporting_options) do
    {
      author: "test_author",
      commit: "abc123",
      service_name: "test_service",
      service_url: "http://example.com"
    }
  end

  subject { described_class.new(sdl, client, reporting_options) }

  describe "#initialize" do
    it "sets the instance variables correctly" do
      expect(subject.instance_variable_get(:@sdl)).to eq(sdl)
      expect(subject.instance_variable_get(:@client)).to eq(client)
      expect(subject.instance_variable_get(:@reporting_options)).to eq(reporting_options)
    end
  end

  describe "#send_report" do
    it "sends the correct mutation to the client" do
      expected_body = {
        query: described_class::REPORT_SCHEMA_MUTATION,
        operationName: "schemaPublish",
        variables: {
          input: {
            sdl: sdl,
            author: reporting_options[:author],
            commit: reporting_options[:commit],
            service: reporting_options[:service_name],
            url: reporting_options[:service_url],
            force: true
          }
        }
      }

      allow(client).to receive(:send)

      subject.send_report

      expect(client).to have_received(:send)
        .with(:"/registry", expected_body, :"report-schema")
        .once
    end
  end
end
