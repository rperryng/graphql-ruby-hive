require "spec_helper"
require "logger"

RSpec.describe GraphQLHive::Configuration do
  let(:logger) { instance_double(Logger) }

  before do
    allow(logger).to receive(:formatter=)
    allow(logger).to receive(:level=)
    allow(logger).to receive(:level)
    allow(logger).to receive(:info)
    allow(logger).to receive(:warn)
    allow(Logger).to receive(:new).and_return(logger)
  end

  let(:valid_options) do
    {
      token: "test-token",
      report_schema: true,
      reporting: {
        author: "test-author",
        commit: "test-commit"
      }
    }
  end

  describe "#initialize" do
    context "with default options" do
      subject(:config) { described_class.new }

      it "sets default values" do
        expect(config.buffer_size).to eq(50)
        expect(config.collect_usage).to be true
        expect(config.collect_usage_sampling).to eq(1.0)
        expect(config.debug).to be false
        expect(config.enabled).to be false # disabled due to missing token
        expect(config.queue_size).to eq(1000)
        expect(config.read_operations).to be true
        expect(config.report_schema).to be false # disabled due to missing reporting info

        client = config.client
        expect(client).to be_a(GraphQLHive::Client)
        expect(client.instance_variable_get(:@token)).to be_nil
        expect(client.instance_variable_get(:@host)).to eq("app.graphql-hive.com")
        expect(client.instance_variable_get(:@port)).to eq("443")
      end

      it "creates a logger with correct settings" do
        expect(config.logger).to be(logger)
        expect(logger).to have_received(:level=).with(Logger::INFO)
      end

      context "when debug is enabled" do
        subject(:config) { described_class.new(debug: true) }

        it "sets logger level to DEBUG" do
          config
          expect(logger).to have_received(:level=).with(Logger::DEBUG)
        end
      end

      it "configures custom formatter" do
        config
        expect(logger).to have_received(:formatter=).with(kind_of(Proc))
      end
    end

    context "with custom options" do
      subject(:config) { described_class.new(valid_options) }

      it "merges custom options with defaults" do
        expect(config.client.instance_variable_get(:@token)).to eq("test-token")
        expect(config.reporting).to include(
          author: "test-author",
          commit: "test-commit"
        )
      end
    end
  end

  describe "#validate!" do
    before { allow(logger).to receive(:warn) }

    context "when token is missing" do
      subject(:config) { described_class.new(logger: logger) }
      it "disables the service and logs a warning" do
        expect(config.enabled).to be false
        expect(config.report_schema).to be false
        expect(logger).to have_received(:warn).with(/token.*missing/)
      end
    end

    context "when author is missing" do
      subject(:config) do
        described_class.new(
          token: "test-token",
          logger: logger,
          reporting: {commit: "test-commit"}
        )
      end

      it "disables schema reporting and logs a warning" do
        expect(config.report_schema).to be false
        expect(logger).to have_received(:warn).with(/author.*commit.*required/)
      end
    end

    context "when commit is missing" do
      subject(:config) do
        described_class.new(
          token: "test-token",
          logger: logger,
          reporting: {author: "test-author"}
        )
      end

      it "disables schema reporting and logs a warning" do
        expect(config.report_schema).to be false
        expect(logger).to have_received(:warn).with(/author.*commit.*required/)
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
