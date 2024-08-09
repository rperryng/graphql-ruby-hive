require 'spec_helper'
require 'ostruct'

RSpec.describe GraphQL::Hive::Sampler::BasicSampler do
  let(:time) { Time.now }
  let(:queries) { [OpenStruct.new(operations: { 'getField' => {} }, query_string: 'query { field }')] }
  let(:results) { [OpenStruct.new(query: OpenStruct.new(context: { header: 'value' }))] }
  let(:duration) { 100 }

  let(:operation) { [time, queries, results, duration] }

  describe '#initialize' do
    it 'sets the sample rate' do
      sampler_instance = described_class.new(0.5)
      expect(sampler_instance.instance_variable_get(:@sample_rate)).to eq(0.5)
    end
  end

  describe '#sample?' do    
    it 'follows the sample rate for all operations' do
      sampler_instance = described_class.new(0)
      expect(sampler_instance.sample?(operation)).to eq(false)
    end

    context 'with at least once sampling' do
      it 'returns true for the first operation, then follows the sample rate for remaining operations' do
        sampler_instance = described_class.new(0, "default")
        expect(sampler_instance.sample?(operation)).to eq(true)
        expect(sampler_instance.sample?(operation)).to eq(false)
      end

      context 'when provided a custom key generator' do
        it 'tracks operations by their custom keys' do
          mock_key_generator = Proc.new { |sample_context| 'same_key' }

          sampler_instance = described_class.new(0, mock_key_generator)

          expect(sampler_instance.sample?(operation)).to eq(true)

          queries = [OpenStruct.new(operations: { 'getDifferentField' => {} }, query_string: 'query { field }')]
          different_operation = [time, queries, results, duration]

          expect(sampler_instance.sample?(different_operation)).to eq(false)
        end
      end
    end
  end
end