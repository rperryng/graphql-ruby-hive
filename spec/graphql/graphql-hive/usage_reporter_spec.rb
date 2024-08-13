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

  let(:schema) { GraphQL::Schema.from_definition('type Query { test: String }') }
  let(:query_string) { 'query TestingHive { test }' }

  before do
    allow(logger).to receive(:warn)
    allow(logger).to receive(:debug)
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
      expect(usage_reporter_instance.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQL::Hive::Sampler::BasicSampler)
    end

    context 'when provided a sampling rate' do
      let(:options) { { collect_usage_sampling_rate: 0.5 } }

      it 'creates a basic sampler' do
        expect(usage_reporter_instance.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQL::Hive::Sampler::BasicSampler)
      end

      context 'using the deprecated field' do
        let(:options) do
          {
            logger: logger,
            collect_usage_sampling: 1
          }
        end

        it 'creates a basic sampler' do
          expect(usage_reporter_instance.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQL::Hive::Sampler::BasicSampler)
        end

        it 'logs a warning' do
          expect(logger).to receive(:warn)
        end
      end
    end

    context 'when provided a sampler' do
      let(:options) { { collect_usage_sampler: proc {} } }

      it 'creates a dynamic sampler' do
        expect(usage_reporter_instance.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQL::Hive::Sampler::DynamicSampler)
      end
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
      RSpec.shared_examples 'a sampler' do |sampler_type|
        let(:sampler_class) { class_double(sampler_type).as_stubbed_const }
        let(:sampler_instance) { instance_double(sampler_type.to_s) }

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

        it 'reports the operation but logs a warning if sampling error' do
          allow(sampler_instance).to receive(:sample?).and_raise(StandardError.new('some_error'))

          expect(sampler_instance).to receive(:sample?).with(operation)
          expect(client).to receive(:send)
          expect(logger).to receive(:warn).with('All operations are sampled because sampling configuration contains an error: some_error')

          usage_reporter_instance.add_operation(operation)
        end
      end

      context 'when provided a sampler' do
        let(:options) do
          {
            logger: logger,
            buffer_size: 1,
            collect_usage_sampler: proc {}
          }
        end

        it_behaves_like 'a sampler', GraphQL::Hive::Sampler::DynamicSampler
      end

      context 'when provided a sampling rate' do
        let(:options) do
          {
            logger: logger,
            buffer_size: 1,
            collect_usage_sampling_rate: 0.5
          }
        end

        it_behaves_like 'a sampler', GraphQL::Hive::Sampler::BasicSampler
      end
    end
  end

  describe '#process_operation' do
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
