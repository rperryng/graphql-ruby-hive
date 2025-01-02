require "spec_helper"
require "logger"

RSpec.describe GraphQL::Hive::Configuration do
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
        expect(config.endpoint).to eq("app.graphql-hive.com")
        expect(config.port).to eq("443")
        expect(config.queue_size).to eq(1000)
        expect(config.read_operations).to be true
        expect(config.report_schema).to be false # disabled due to missing reporting info
      end

      it "creates a logger with correct settings" do
        expect(config.logger).to be_a(Logger)
        expect(config.logger.level).to eq(Logger::INFO)
      end

      context "when debug is enabled" do
        subject(:config) { described_class.new(debug: true) }

        it "sets logger level to DEBUG" do
          expect(config.logger.level).to eq(Logger::DEBUG)
        end
      end

      it "configures custom formatter" do
        # Test the formatter by capturing output
        output = StringIO.new
        config.logger.instance_variable_set(:@logdev, Logger::LogDevice.new(output))
        config.logger.info("test message")

        expect(output.string).to include("[hive]")
        expect(output.string).to include("test message")
      end
    end

    context "with custom options" do
      subject(:config) { described_class.new(valid_options) }

      it "merges custom options with defaults" do
        expect(config.token).to eq("test-token")
        expect(config.reporting).to include(
          author: "test-author",
          commit: "test-commit"
        )
      end
    end
  end

  describe "#validate!" do
    let(:logger) { instance_double(Logger) }

    before { allow(logger).to receive(:warn) }

    context "when token is missing" do
      subject(:config) { described_class.new(logger: logger) }
      it "disables the service and logs a warning" do
        expect(config.enabled).to be false
        expect(config.report_schema).to be false
        expect(logger).to have_received(:warn).with(/token.*missing/)
      end
    end

    context "when reporting info is incomplete" do
      subject(:config) { described_class.new(token: "test-token", logger: logger) }

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
