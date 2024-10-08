# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraphQL::Hive::UsageReporter do
  let(:logger) { instance_double("Logger", debug: nil) }
  let(:reporting_thread) { instance_double("GraphQL::Hive::ReportingThread") }
  let(:queue) { instance_double("Queue") }
  let(:reporter) {
    described_class.new(
      reporting_thread: reporting_thread,
      queue: queue,
      logger: logger
    )
  }

  describe ".instance" do
    it "returns the singleton instance" do
      instance = described_class.new(
        reporting_thread: reporting_thread,
        queue: queue,
        logger: logger
      )
      expect(described_class.instance).to eq(instance)
    end
  end

  describe "#initialize" do
    it "initializes with the correct instance variables and starts the thread" do
      expect(reporter.instance_variable_get(:@queue)).to be(queue)
      expect(reporter.instance_variable_get(:@reporting_thread)).to be(reporting_thread)
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
      allow(reporting_thread).to receive(:start_thread)
      reporter.on_start
      expect(reporting_thread).to have_received(:start_thread)
    end
  end

  describe "#on_exit" do
    it "joins the thread" do
      reporting_thread = reporter.instance_variable_get(:@reporting_thread)
      allow(reporting_thread).to receive(:join_thread)
      reporter.on_exit
      expect(reporting_thread).to have_received(:join_thread)
    end
  end
end
