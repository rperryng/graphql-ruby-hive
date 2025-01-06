# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraphQL::Hive::UsageReporter do
  subject(:usage_reporter) do
    described_class.new(
      buffer_size: buffer_size,
      client: client,
      sampler: GraphQL::Hive::Sampler.new(sampling_options: 1.0, logger: logger),
      queue: Thread::SizedQueue.new(1000),
      logger: logger
    )
  end
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
    usage_reporter.on_exit
  end

  describe "#initialize" do
    it "sets the instance" do
      expect(usage_reporter.instance_variable_get(:@client)).to eq(client)
      expect(usage_reporter.instance_variable_get(:@queue)).to be_an_instance_of(Thread::SizedQueue)
      expect(usage_reporter.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQL::Hive::Sampler)
      expect(usage_reporter.instance_variable_get(:@logger)).to be(logger)
    end
  end

  describe "#add_operation" do
    it "adds an operation to the queue" do
      operation = {operation: "test"}
      usage_reporter.add_operation(operation)
      expect(usage_reporter.instance_variable_get(:@queue).pop).to eq(operation)
    end

    describe "when the queue is full" do
      subject(:usage_reporter) do
        described_class.new(
          buffer_size: 1,
          client: client,
          sampler: GraphQL::Hive::Sampler.new(sampling_options: 1.0, logger: logger),
          queue: Thread::SizedQueue.new(1),
          logger: logger
        )
      end

      it "logs an error" do
        allow(logger).to receive(:error)
        usage_reporter.add_operation("operation 1")
        usage_reporter.add_operation("operation 2")
        expect(logger).to have_received(:error).with("SizedQueue is full, discarding operation. Size: 1, Max: 1")
      end
    end
  end

  describe "#on_exit" do
    it "closes the queue and joins the thread" do
      allow(usage_reporter.instance_variable_get(:@queue)).to receive(:close)
      allow(usage_reporter.instance_variable_get(:@thread)).to receive(:join)
      usage_reporter.on_exit
      expect(usage_reporter.instance_variable_get(:@queue)).to have_received(:close)
      expect(usage_reporter.instance_variable_get(:@thread)).to have_received(:join)
    end
  end

  describe "#on_start" do
    it "starts the thread" do
      expect(usage_reporter).to receive(:start_thread)
      usage_reporter.on_start
    end
  end

  describe "#start_thread" do
    it "logs a warning if the thread is already alive" do
      usage_reporter.instance_variable_set(
        :@thread,
        Thread.new do
          # do nothing
        end
      )
      expect(logger).to receive(:warn)
      usage_reporter.on_start
    end

    context "when configured with sampling" do
      # TODO: this test is not working as expected because it expects things that happen inside a thread
      subject(:usage_reporter) do
        described_class.new(
          buffer_size: buffer_size,
          client: client,
          sampler: sampler,
          queue: Thread::SizedQueue.new(1),
          logger: logger
        )
      end

      let(:sampler) { instance_double("GraphQL::Hive::Sampler", sample?: true) }

      before do
        allow(client).to receive(:send)
      end

      it "reports the operation if it should be included" do
        skip "does not test well with thread"
        usage_reporter.add_operation(operation)
        expect(sampler).to have_received(:sample?).with(operation)
        expect(client).to have_received(:send)
      end

      it "does not report the operation if it should not be included" do
        skip "does not test well with thread"
        allow(sampler).to receive(:sample?).and_return(false)
        usage_reporter.add_operation(operation)
        expect(sampler).to have_received(:sample?).with(operation)
        expect(client).not_to have_received(:send)
      end
    end

    context "with erroneous operations" do
      subject(:usage_reporter) do
        described_class.new(
          buffer_size: buffer_size,
          client: client,
          sampler: sampler,
          queue: Thread::SizedQueue.new(1),
          logger: logger
        )
      end

      let(:sampler) { instance_double("GraphQL::Hive::Sampler") }
      let(:schema) { GraphQL::Schema.from_definition("type Query { test: String }") }
      let(:queries_valid) { [GraphQL::Query.new(schema, "query TestingHiveValid { test }", variables: {})] }
      let(:queries_invalid) { [GraphQL::Query.new(schema, "query TestingHiveInvalid { test }", variables: {})] }
      let(:results) { [GraphQL::Query::Result.new(query: queries_valid[0], values: {"data" => {"test" => "test"}})] }
      let(:buffer_size) { 1 }

      it "can still process the operations after erroneous operation" do
        raise_exception = true
        operation_error = StandardError.new("First operation")
        allow(sampler).to receive(:sample?) do |_operation|
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
          usage_reporter.add_operation([timestamp, queries_invalid, results, duration])
          logger_condition.wait(mutex)

          usage_reporter.add_operation([timestamp, queries_valid, results, duration])
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
      usage_reporter.send(:process_operations, [operation])
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
