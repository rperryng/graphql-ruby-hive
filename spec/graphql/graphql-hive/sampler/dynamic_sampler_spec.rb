require 'spec_helper'
require 'ostruct'

RSpec.describe GraphQL::Hive::Sampler::DynamicSampler do
  let(:time) { Time.now }
  let(:queries) { [OpenStruct.new(operations: { 'getField' => {} }, query_string: 'query { field }')] }
  let(:results) { [OpenStruct.new(query: OpenStruct.new(context: { header: 'value' }))] }
  let(:duration) { 100 }

  let(:operation) { [time, queries, results, duration] }

  describe '#initialize' do
    it 'sets the sampler and tracked operations hash' do
      mock_sampler = Proc.new { |sample_context| 1 }
      sampler_instance = described_class.new(mock_sampler)

      expect(sampler_instance.instance_variable_get(:@sampler)).to eq(mock_sampler)
      expect(sampler_instance.instance_variable_get(:@tracked_operations)).to eq({})
    end
  end

  describe '#sample?' do
    before do
      mock_document = GraphQL::Language::Nodes::Document.new(definitions: [])
      allow(GraphQL).to receive(:parse).and_return(mock_document)
    end

    it 'follows the sampler for all operations' do
      mock_sampler = Proc.new { |sample_context| 0 }

      sampler_instance = described_class.new(mock_sampler)
      expect(sampler_instance.sample?(operation)).to eq(false)
    end

    it 'raises an error if the sampler does not return a number' do
      mock_sampler = Proc.new { |sample_context| 'string' }

      sampler_instance = described_class.new(mock_sampler)
      expect { sampler_instance.sample?(operation) }.to raise_error(StandardError, "Error calling sampler: Sampler must return a number")
    end

    context 'with at least once sampling' do
      it 'returns true for the first operation, then follows the sampler for remaining operations' do
        mock_sampler = Proc.new { |sample_context| 0 }

        sampler_instance = described_class.new(mock_sampler, "default")
        expect(sampler_instance.sample?(operation)).to eq(true)
        expect(sampler_instance.sample?(operation)).to eq(false)
      end

      context 'when provided a custom key generator' do
        it 'tracks operations by their custom keys' do
          mock_sampler = Proc.new { |sample_context| 0 }
          mock_operation_key_generator = Proc.new { |sample_context| 'same_key' }

          sampler_instance = described_class.new(mock_sampler, mock_operation_key_generator)

          expect(sampler_instance.sample?(operation)).to eq(true)

          queries = [OpenStruct.new(operations: { 'getDifferentField' => {} }, query_string: 'query { field }')]
          different_operation = [time, queries, results, duration]

          expect(sampler_instance.sample?(different_operation)).to eq(false)
        end
      end
    end
  end
end