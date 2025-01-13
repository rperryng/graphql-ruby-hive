RSpec.describe GraphQLHive::SchemaReporter do
  let(:sdl) { "type Query { hello: String }" }
  let(:options) do
    {
      author: "test_author",
      commit: "abc123",
      service: "test-service",
      url: "http://test.com",
      force: true
    }
  end
  let(:config) { instance_double(GraphQLHive::Configuration) }
  let(:client) { instance_double(GraphQLHive::Client) }

  before do
    allow(GraphQLHive).to receive(:configuration).and_return(config)
    allow(config).to receive(:client).and_return(client)
  end

  subject { described_class.new(sdl: sdl, options: options) }

  describe "#initialize" do
    it "sets the instance variables correctly" do
      expect(subject.instance_variable_get(:@sdl)).to eq(sdl)
      expect(subject.instance_variable_get(:@options)).to eq(options)
      expect(subject.instance_variable_get(:@client)).to eq(client)
    end
  end

  describe "#send_report" do
    context "with valid reporting options" do
      it "sends the correct mutation to the client" do
        expected_body = {
          query: described_class::REPORT_SCHEMA_MUTATION,
          operationName: "schemaPublish",
          variables: {
            input: {
              sdl: sdl,
              author: options[:author],
              commit: options[:commit],
              service: options[:service],
              url: options[:url],
              force: options[:force]
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

    context "with invalid reporting options" do
      context "when author is missing" do
        let(:options) { {commit: "abc123"} }

        it "raises an ArgumentError" do
          expect { subject.send_report }.to raise_error(
            ArgumentError,
            "author is required for schema reporting"
          )
        end
      end

      context "when commit is missing" do
        let(:options) { {author: "test_author"} }

        it "raises an ArgumentError" do
          expect { subject.send_report }.to raise_error(
            ArgumentError,
            "commit is required for schema reporting"
          )
        end
      end
    end
  end
end
