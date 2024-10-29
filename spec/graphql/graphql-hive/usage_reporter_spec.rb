# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraphQL::Hive::UsageReporter do
  let(:usage_reporter_instance) { described_class.new(options, client) }
  let(:options) { {logger: logger, buffer_size: buffer_size} }
  let(:logger) { instance_double("Logger") }
  let(:client) { instance_double("Hive::Client") }
  let(:buffer_size) { 1 }

  let(:timestamp) { 1_720_705_946_333 }
  let(:queries) { [] }
  let(:results) { [] }
  let(:duration) { 100_000 }
  let(:operation) { [timestamp, queries, results, duration] }

  before do
    allow(logger).to receive(:warn)
    allow(logger).to receive(:debug)
    allow(logger).to receive(:error)
  end

  # NOTE: creating a new instance of usage_reporter starts a new thread, so we must call on_exit after each test to close the thread

  after do
    usage_reporter_instance.on_exit
  end

  describe "#initialize" do
    it "sets the instance" do
      expect(usage_reporter_instance.instance_variable_get(:@options)).to eq(options)
      expect(usage_reporter_instance.instance_variable_get(:@client)).to eq(client)

      expect(usage_reporter_instance.instance_variable_get(:@options_mutex)).to be_an_instance_of(Mutex)
      expect(usage_reporter_instance.instance_variable_get(:@queue)).to be_an_instance_of(GraphQL::Hive::BoundedQueue)
      expect(usage_reporter_instance.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQL::Hive::Sampler)
    end
  end

  describe "#add_operation" do
    it "adds an operation to the queue" do
      operation = {operation: "test"}
      usage_reporter_instance.add_operation(operation)
      expect(usage_reporter_instance.instance_variable_get(:@queue).pop).to eq(operation)
    end
  end

  describe "#on_exit" do
    it "closes the queue and joins the thread" do
      usage_reporter_instance = described_class.new(options, client)

      expect(usage_reporter_instance.instance_variable_get(:@queue)).to receive(:close)
      expect(usage_reporter_instance.instance_variable_get(:@thread)).to receive(:join)

      usage_reporter_instance.on_exit
    end
  end

  describe "#on_start" do
    it "starts the thread" do
      expect(usage_reporter_instance).to receive(:start_thread)
      usage_reporter_instance.on_start
    end
  end

  describe "#start_thread" do
    it "logs a warning if the thread is already alive" do
      thread = Thread.new do
        # do nothing
      end
      usage_reporter_instance.instance_variable_set(:@thread, thread)
      expect(logger).to receive(:warn)
      usage_reporter_instance.on_start
      thread.join
    end

    context "when configured with sampling" do
      let(:options) do
        {
          logger: logger,
          buffer_size: 1
        }
      end

      let(:sampler_class) { class_double(GraphQL::Hive::Sampler).as_stubbed_const }
      let(:sampler_instance) { instance_double("GraphQL::Hive::Sampler") }

      before do
        allow(sampler_class).to receive(:new).and_return(sampler_instance)
        allow(client).to receive(:send)
      end

      it "reports the operation if it should be included" do
        allow(sampler_instance).to receive(:sample?).and_return(true)

        expect(sampler_instance).to receive(:sample?).with(operation)
        expect(client).to receive(:send)

        usage_reporter_instance.add_operation(operation)
      end

      it "does not report the operation if it should not be included" do
        allow(sampler_instance).to receive(:sample?).and_return(false)

        expect(sampler_instance).to receive(:sample?).with(operation)
        expect(client).not_to receive(:send)

        usage_reporter_instance.add_operation(operation)
      end
    end

    context "with erroneous operations" do
      let(:sampler_class) { class_double(GraphQL::Hive::Sampler).as_stubbed_const }
      let(:sampler_instance) { instance_double("GraphQL::Hive::Sampler") }
      let(:schema) { GraphQL::Schema.from_definition("type Query { test: String }") }
      let(:queries_valid) { [GraphQL::Query.new(schema, "query TestingHiveValid { test }", variables: {})] }
      let(:queries_invalid) { [GraphQL::Query.new(schema, "query TestingHiveInvalid { test }", variables: {})] }
      let(:results) { [GraphQL::Query::Result.new(query: queries_valid[0], values: {"data" => {"test" => "test"}})] }
      let(:buffer_size) { 1 }

      before do
        allow(sampler_class).to receive(:new).and_return(sampler_instance)
      end

      it "can still process the operations after erroneous operation" do
        raise_exception = true
        operation_error = StandardError.new("First operation")
        allow(sampler_instance).to receive(:sample?) do |_operation|
          if raise_exception
            raise_exception = false
            raise operation_error
          else
            true
          end
        end

        mutex = Mutex.new
        logger_condition = ConditionVariable.new
        client_condition = ConditionVariable.new
        allow(logger).to receive(:error) do |_e|
          mutex.synchronize { logger_condition.signal }
        end

        allow(client).to receive(:send) do |_endpoint|
          mutex.synchronize { client_condition.signal }
        end

        mutex.synchronize do
          usage_reporter_instance.add_operation([timestamp, queries_invalid, results, duration])
          logger_condition.wait(mutex)

          usage_reporter_instance.add_operation([timestamp, queries_valid, results, duration])
          client_condition.wait(mutex)
        end

        expect(client).to have_received(:send).once.with(
          :"/usage",
          {
            map: {"a69918853baf60d89b871e1fbe13915b" =>
                     {
                       fields: ["Query", "Query.test"],
                       operation: "query TestingHiveValid {\n  test\n}",
                       operationName: "TestingHiveValid"
                     }},
            operations: [{
              execution: {duration: 100000, errorsTotal: 0, ok: true},
              operationMapKey: "a69918853baf60d89b871e1fbe13915b",
              timestamp: 1720705946333
            }],
            size: 1
          },
          :usage
        )
        expect(logger).to have_received(:error).with(operation_error).once
      end
    end
  end

  describe "#process_operation" do
    let(:schema) { GraphQL::Schema.from_definition("type Query { test: String }") }
    let(:query_string) { "query TestingHive { test }" }
    let(:queries) { [GraphQL::Query.new(schema, query_string, variables: {})] }
    let(:results) { [GraphQL::Query::Result.new(query: queries.first, values: {"data" => {"test" => "test"}})] }

    before do
      allow(client).to receive(:send)
    end

    it "processes and reports the operation to the client" do
      usage_reporter_instance.send(:process_operations, [operation])
      expect(client).to have_received(:send).with(
        :"/usage",
        {
          map: {"8b8412ce86f3ea7accb931b1a5de335d" =>
            {
              fields: %w[Query Query.test],
              operation: "query TestingHive {\n  test\n}",
              operationName: "TestingHive"
            }},
          operations: [
            {
              execution: {duration: 100_000, errorsTotal: 0, ok: true},
              operationMapKey: "8b8412ce86f3ea7accb931b1a5de335d",
              timestamp: 1_720_705_946_333
            }
          ],
          size: 1
        },
        :usage
      )
    end
  end
end
