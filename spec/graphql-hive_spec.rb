# frozen_string_literal: true

RSpec.describe GraphQLHive do
  let(:schema) { Class.new(GraphQL::Schema) }
  let(:author) { "test author" }
  let(:commit) { "test commit" }
  let(:config) do
    GraphQLHive.configure do |c|
      c.token = "test-token"
      c.enabled = true
      c.schema = schema
    end
  end

  before do
    GraphQLHive.configuration = nil
  end

  describe ".configure" do
    it "yields configuration object" do
      expect { |b| GraphQLHive.configure(&b) }.to yield_with_args(GraphQLHive::Configuration)
    end

    it "returns configuration object" do
      expect(GraphQLHive.configure).to be_a(GraphQLHive::Configuration)
    end

    it "validates configuration" do
      config = GraphQLHive.configure
      expect(config.logger).not_to be_nil
    end

    it "stores configuration" do
      config = GraphQLHive.configure
      expect(GraphQLHive.configuration).to eq(config)
    end
  end

  describe ".start" do
    it "starts the usage reporter" do
      config
      expect(GraphQLHive.configuration.usage_reporter).to receive(:start)
      GraphQLHive.start
    end
  end

  describe ".stop" do
    it "stops the usage reporter" do
      config
      expect(GraphQLHive.configuration.usage_reporter).to receive(:stop)
      GraphQLHive.stop
    end
  end

  describe ".report_schema_to_hive" do
    let(:reporter) { instance_double(GraphQLHive::SchemaReporter) }
    let(:sdl) { "type Query { test: String }" }

    before do
      config
      allow(GraphQL::Schema::Printer).to receive(:new).with(schema).and_return(double(print_schema: sdl))
      allow(GraphQLHive::SchemaReporter).to receive(:new).and_return(reporter)
      allow(reporter).to receive(:send_report)
    end

    it "sends schema report" do
      GraphQLHive.report_schema_to_hive(schema: schema, options: {author: author, commit: commit})
      expect(reporter).to have_received(:send_report)
    end

    it "creates reporter with correct params" do
      options = {
        author: author,
        commit: commit
      }
      GraphQLHive.report_schema_to_hive(schema: schema, options: options)
      expect(GraphQLHive::SchemaReporter).to have_received(:new).with(
        sdl: sdl,
        options: options
      )
    end
  end
end
