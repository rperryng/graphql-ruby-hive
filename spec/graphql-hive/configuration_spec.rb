require "spec_helper"
require "logger"

RSpec.describe GraphQLHive::Configuration do
  subject(:config) { described_class.new }
  let(:logger) { instance_double(Logger) }
  let(:valid_options) do
    {
      token: "test-token"
    }
  end

  before do
    allow(logger).to receive(:formatter=)
    allow(logger).to receive(:level=)
    allow(logger).to receive(:level)
    allow(logger).to receive(:info)
    allow(logger).to receive(:warn)
    allow(Logger).to receive(:new).and_return(logger)
  end

  describe "#initialize" do
    context "with default options" do
      it "sets default values" do
        expect(config.buffer_size).to eq(50)
        expect(config.collect_usage).to be true
        expect(config.collect_usage_sampling).to eq(1.0)
        expect(config.debug).to be false
        expect(config.enabled).to be true
        expect(config.queue_size).to eq(1000)
        expect(config.read_operations).to be true

        client = config.client
        expect(client).to be_a(GraphQLHive::Client)
        expect(client.instance_variable_get(:@token)).to be_nil
        expect(client.instance_variable_get(:@host)).to eq("app.graphql-hive.com")
        expect(client.instance_variable_get(:@port)).to eq("443")
      end
    end

    context "with custom options" do
      subject(:config) { described_class.new(valid_options) }

      it "merges custom options with defaults" do
        expect(config.client.instance_variable_get(:@token)).to eq("test-token")
      end
    end
  end

  describe "#validate!" do
    before do
      allow(logger).to receive(:warn)
      config.validate!
    end

    it "creates a logger with correct settings" do
      expect(config.logger).to be(logger)
      expect(logger).to have_received(:level=).with(Logger::INFO)
    end

    context "when debug is enabled" do
      subject(:config) { described_class.new(debug: true) }

      it "sets logger level to DEBUG" do
        expect(logger).to have_received(:level=).with(Logger::DEBUG)
      end
    end

    it "configures custom formatter" do
      expect(logger).to have_received(:formatter=).with(kind_of(Proc))
    end

    context "when token is missing" do
      subject(:config) { described_class.new(logger: logger) }

      it "disables the service and logs a warning" do
        expect(config.enabled).to be false
        expect(logger).to have_received(:warn).with(/token.*missing/)
      end
    end

    context "with valid configuration" do
      subject(:config) { described_class.new(valid_options) }

      it "keeps the service enabled" do
        expect(config.enabled).to be true
        expect(logger).not_to have_received(:warn)
      end
    end
  end
end
