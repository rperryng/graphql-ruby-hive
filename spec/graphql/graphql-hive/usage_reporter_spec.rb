# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GraphQL::Hive::UsageReporter do
  let(:subject) { described_class.instance }
  let(:client) { instance_double('Hive::Client') }
  let(:options) do
    {
      logger: logger,
      buffer_size: 1
    }
  end
  let(:logger) { instance_double('Logger') }

  let(:timestamp) { 1_720_705_946_333 }
  let(:queries) { [] }
  let(:results) { [] }
  let(:duration) { 100_000 }
  let(:operation) { [timestamp, queries, results, duration] }

  let(:schema) { GraphQL::Schema.from_definition('type Query { test: String }') }
  let(:query_string) { 'query TestingHive { test }' }

  before do
    allow(logger).to receive(:warn)
    allow(logger).to receive(:debug)
  end

  describe '#initialize' do
    it 'sets the instance' do
      expect(described_class.instance).to eq(nil)
      described_class.new(options, client)
      expect(described_class.instance).to_not eq(nil)
    end

    context 'when provided a sampler' do
      let(:client_sampler) { Proc.new {} }

      it 'creates the sampler' do
        described_class.new(options.merge(collect_usage_sampler: client_sampler), client)
        expect(subject.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQL::Hive::DynamicSampler)
      end
    end
  end

  describe '#add_operation' do
    it 'adds an operation to the queue' do
      operation = { operation: 'test' }
      described_class.new(options, client)
      subject.add_operation(operation)
      expect(subject.instance_variable_get(:@queue).pop).to eq(operation)
    end
  end

  describe '#on_exit' do
    it 'closes the queue and joins the thread' do
      described_class.new(options, client)
      expect(subject.instance_variable_get(:@queue)).to receive(:close)
      expect(subject.instance_variable_get(:@thread)).to receive(:join)
      subject.on_exit
    end
  end

  describe '#on_start' do
    it 'starts the thread' do
      described_class.new(options, client)
      expect(subject).to receive(:start_thread)
      subject.on_start
    end
  end

  describe '#start_thread' do
    it 'logs a warning if the thread is already alive' do
      described_class.new(options, client)
      subject.instance_variable_set(:@thread, Thread.new {})
      expect(logger).to receive(:warn)
      subject.on_start
    end
    
    context 'when provided a sampler' do
      let(:client_sampler) { Proc.new {} }
      let(:options) do
        {
          logger: logger,
          buffer_size: 1,
          collect_usage_sampler: client_sampler
        }
      end
      
      let(:sampler_class_double) { class_double(GraphQL::Hive::DynamicSampler).as_stubbed_const }
      let(:sampler_instance) { instance_double('GraphQL::Hive::DynamicSampler') }

      before do
        allow(sampler_class_double).to receive(:new).and_return(sampler_instance)
        allow(sampler_instance).to receive(:sample?)
        allow(client).to receive(:send)
      end

      it 'adds the operation to the buffer if it should be included' do
        reporter_instance = described_class.new(options, client)
        allow(sampler_instance).to receive(:sample?).and_return(true)

        reporter_instance.add_operation(operation)

        reporter_instance.on_start
        expect(sampler_instance).to have_received(:sample?).with(operation)
        expect(client).to have_received(:send)
      end

      # TODO: fix
      it 'does not add the operation to the buffer if it should not be included' do
        reporter_instance = described_class.new(options, client)
        allow(sampler_instance).to receive(:sample?).and_return(false)

        reporter_instance.add_operation(operation)

        reporter_instance.on_start
        expect(sampler_instance).to have_received(:sample?).with(operation)
        expect(client).not_to have_received(:send)
      end
    end
  end

  describe '#process_operation' do
    let(:queries) { [GraphQL::Query.new(schema, query_string, variables: {})]}
    let(:results) { [GraphQL::Query::Result.new(query: queries.first, values: { 'data' => { 'test' => 'test' } })] }

    before do
      allow(client).to receive(:send)
    end

    it 'processes and reports the operation to the client' do
      described_class.new(options, client)
      subject.send(:process_operations, [operation])

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