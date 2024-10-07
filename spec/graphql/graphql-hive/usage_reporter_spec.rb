# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraphQL::Hive::UsageReporter do
  let(:logger) { instance_double("Logger", debug: nil) }
  let(:options) do
    {
      logger: logger,
      collect_usage_sampling: 0.5,
      buffer_size: 2,
      client_info: ->(_context) { {name: "test_client"} }
    }
  end
  let(:client) { instance_double("GraphQL::Hive::Client") }
  let(:thread_manager) { instance_double("GraphQL::Hive::ThreadManager", start_thread: nil, join_thread: nil) }
  let(:sampler) { instance_double("GraphQL::Hive::Sampler", sample?: true) }

  before do
    allow(GraphQL::Hive::Sampler).to receive(:new).and_return(sampler)
    allow(GraphQL::Hive::ThreadManager).to receive(:new).and_return(thread_manager)
  end

  describe ".instance" do
    it "returns the singleton instance" do
      reporter = described_class.new(options, client)
      expect(described_class.instance).to eq(reporter)
    end
  end

  describe "#initialize" do
    it "initializes with the correct instance variables and starts the thread" do
      reporter = described_class.new(options, client)
      expect(reporter.instance_variable_get(:@options)).to eq(options)
      expect(reporter.instance_variable_get(:@client)).to eq(client)
      expect(reporter.instance_variable_get(:@queue)).to be_a(Queue)
      expect(reporter.instance_variable_get(:@sampler)).to eq(sampler)
      expect(reporter.instance_variable_get(:@thread_manager)).to eq(thread_manager)
      expect(thread_manager).to have_received(:start_thread)
    end
  end

  describe "#add_operation" do
    it "adds an operation to the queue" do
      reporter = described_class.new(options, client)
      operation = double("operation")
      queue = reporter.instance_variable_get(:@queue)

      expect(queue).to receive(:push).with(operation)
      reporter.add_operation(operation)
    end
  end

  describe "#on_exit" do
    it "joins the thread" do
      reporter = described_class.new(options, client)
      expect(thread_manager).to receive(:join_thread)
      reporter.on_exit
    end
  end

  describe "#on_start" do
    it "starts the thread" do
      reporter = described_class.new(options, client)
      expect(thread_manager).to receive(:start_thread)
      reporter.on_start
    end
  end
end
