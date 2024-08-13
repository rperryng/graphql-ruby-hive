# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GraphQL::Hive::UsageReporter do
  let(:usage_reporter_instance) { described_class.new(options, client) }
  let(:options) { { logger: logger } }
  let(:logger) { instance_double('Logger') }
  let(:client) { instance_double('Hive::Client') }

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

  describe '#initialize' do
    it 'sets the instance' do
      expect(usage_reporter_instance.instance_variable_get(:@options)).to eq(options)
      expect(usage_reporter_instance.instance_variable_get(:@client)).to eq(client)

      expect(usage_reporter_instance.instance_variable_get(:@options_mutex)).to be_an_instance_of(Mutex)
      expect(usage_reporter_instance.instance_variable_get(:@queue)).to be_an_instance_of(Queue)
      expect(usage_reporter_instance.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQL::Hive::Sampler)
    end
  end

  describe '#add_operation' do
    it 'adds an operation to the queue' do
      operation = { operation: 'test' }
      usage_reporter_instance.add_operation(operation)
      expect(usage_reporter_instance.instance_variable_get(:@queue).pop).to eq(operation)
    end
  end

  describe '#on_exit' do
    it 'closes the queue and joins the thread' do
      usage_reporter_instance = described_class.new(options, client)

      expect(usage_reporter_instance.instance_variable_get(:@queue)).to receive(:close)
      expect(usage_reporter_instance.instance_variable_get(:@thread)).to receive(:join)

      usage_reporter_instance.on_exit
    end
  end

  describe '#on_start' do
    it 'starts the thread' do
      expect(usage_reporter_instance).to receive(:start_thread)
      usage_reporter_instance.on_start
    end
  end

  describe '#start_thread' do
    it 'logs a warning if the thread is already alive' do
      usage_reporter_instance.instance_variable_set(:@thread, Thread.new do
        # do nothing
      end)
      expect(logger).to receive(:warn)
      usage_reporter_instance.on_start
    end

    context 'when configured with sampling' do
      let(:options) do
        {
          logger: logger,
          buffer_size: 1
        }
      end

      let(:sampler_class) { class_double(GraphQL::Hive::Sampler).as_stubbed_const }
      let(:sampler_instance) { instance_double('GraphQL::Hive::Sampler') }

      before do
        allow(sampler_class).to receive(:new).and_return(sampler_instance)
        allow(client).to receive(:send)
      end

      it 'reports the operation if it should be included' do
        allow(sampler_instance).to receive(:sample?).and_return(true)

        expect(sampler_instance).to receive(:sample?).with(operation)
        expect(client).to receive(:send)

        usage_reporter_instance.add_operation(operation)
      end

      it 'does not report the operation if it should not be included' do
        allow(sampler_instance).to receive(:sample?).and_return(false)

        expect(sampler_instance).to receive(:sample?).with(operation)
        expect(client).not_to receive(:send)

        usage_reporter_instance.add_operation(operation)
      end
    end
  end

  describe '#process_operation' do
    let(:schema) { GraphQL::Schema.from_definition('type Query { test: String }') }
    let(:query_string) { 'query TestingHive { test }' }
    let(:queries) { [GraphQL::Query.new(schema, query_string, variables: {})] }
    let(:results) { [GraphQL::Query::Result.new(query: queries.first, values: { 'data' => { 'test' => 'test' } })] }

    before do
      allow(client).to receive(:send)
    end

    it 'processes and reports the operation to the client' do
      usage_reporter_instance.send(:process_operations, [operation])
      expect(client).to have_received(:send).with(
        '/usage',
        {
          map: { '8b8412ce86f3ea7accb931b1a5de335d' =>
            {
              fields: %w[Query Query.test],
              operation: "query TestingHive {\n  test\n}",
              operationName: 'TestingHive'
            } },
          operations: [
            {
              execution: { duration: 100_000, errors: [], errorsTotal: 0, ok: true },
              operationMapKey: '8b8412ce86f3ea7accb931b1a5de335d',
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
