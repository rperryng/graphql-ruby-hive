# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraphQL::Hive::UsageReporter do
  let(:logger) { instance_double("Logger", debug: nil) }
  let(:options) do
    {
      logger: logger,
      collect_usage_sampling: {
        sample_rate: 0.5
      },
      buffer_size: 2,
      client_info: ->(_context) { {name: "test_client"} }
    }
  end
  let(:reporter) {
    described_class.new(
      options: options,
      logger: logger
    )
  }

  describe ".instance" do
    it "returns the singleton instance" do
      instance = described_class.new(
        options: options,
        logger: logger
      )
      expect(described_class.instance).to eq(instance)
    end
  end

  describe "#initialize" do
    it "initializes with the correct instance variables and starts the thread" do
      expect(reporter.instance_variable_get(:@queue)).to be_a(Queue)
      expect(reporter.instance_variable_get(:@reporting_thread)).to be_a(GraphQL::Hive::ReportingThread)
    end
  end

  describe "#add_operation" do
    it "adds an operation to the queue" do
      operation = double("operation")
      queue = reporter.instance_variable_get(:@queue)

      expect(queue).to receive(:push).with(operation)
      reporter.add_operation(operation)
    end
  end

  describe "#on_start" do
    it "starts the thread" do
      reporting_thread = reporter.instance_variable_get(:@reporting_thread)
      allow(reporting_thread).to receive(:start_thread).and_call_original
      reporter.on_start
      expect(reporting_thread).to have_received(:start_thread)
      reporter.on_exit
    end
  end

  describe "#on_exit" do
    it "joins the thread" do
      reporting_thread = reporter.instance_variable_get(:@reporting_thread)
      allow(reporting_thread).to receive(:join_thread).and_call_original
      reporter.on_start
      reporter.on_exit
      expect(reporting_thread).to have_received(:join_thread)
    end
  end
end
