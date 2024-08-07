require 'spec_helper'
require 'ostruct'

RSpec.describe GraphQL::Hive::Sampler do
  let(:time) { Time.now }
  let(:queries) { [OpenStruct.new(operations: { 'getField' => {} })] }
  let(:results) { [OpenStruct.new(query: OpenStruct.new(context: { header: 'value' }))] }
  let(:duration) { 100 }

  let(:operation) { [time, queries, results, duration] }

  describe '#initialize' do
    describe 'when provided a sampler' do
      it 'sets the sampler and tracked operations hash' do
        mock_sampler = Proc.new { |sample_context| 1 }
        sampler_instance = described_class.new(mock_sampler)
        expect(sampler_instance.instance_variable_get(:@sample_rate)).to eq(nil)
        expect(sampler_instance.instance_variable_get(:@sampler)).to eq(mock_sampler)
        expect(sampler_instance.instance_variable_get(:@tracked_operations)).to eq({})
      end
    end

    describe 'when provided a sample rate'do 
      it 'sets the sample rate' do
        sampler_instance = described_class.new(0)
        expect(sampler_instance.instance_variable_get(:@sample_rate)).to eq(0)
        expect(sampler_instance.instance_variable_get(:@sampler)).to eq(nil)
        expect(sampler_instance.instance_variable_get(:@tracked_operations)).to eq(nil)
      end
    end

    describe 'no sample rate or sampler provided' do
      it 'sets the sample rate to 1' do
        sampler_instance = described_class.new(nil)
        expect(sampler_instance.instance_variable_get(:@sample_rate)).to eq(1)
        expect(sampler_instance.instance_variable_get(:@sampler)).to eq(nil)
        expect(sampler_instance.instance_variable_get(:@tracked_operations)).to eq(nil)
      end
    end
  end

  describe '#should_include' do
    describe 'when provided a sampler' do
      it 'returns true for the first operation and follows the sampler for remaining operations' do
        mock_sampler = Proc.new { |sample_context| 0 }
        sampler_instance = described_class.new(mock_sampler)
        expect(sampler_instance.should_include(operation)).to eq(true)
        expect(sampler_instance.should_include(operation)).to eq(false)
      end

      it 'raises an error if the sampler does not return a number' do
        mock_sampler = Proc.new { |sample_context| 'string' }
        sampler_instance = described_class.new(mock_sampler)
        expect { sampler_instance.should_include(operation) }.to raise_error(StandardError, "Sampler must return a number")
      end

      describe 'when provided an operation key generator' do
        it 'uses the operation key generator to track operations' do
          mock_sampler = Proc.new { |sample_context| 0 }
          mock_operation_key_generator = Proc.new { |sample_context| 'same_key' }
          sampler_instance = described_class.new(mock_sampler, mock_operation_key_generator)
          expect(sampler_instance.should_include(operation)).to eq(true)
          expect(sampler_instance.should_include('different_operation')).to eq(false)
        end
      end
    end
    
    describe 'when provided a sample rate'do 
      it 'follows the sample rate for all operations' do
        sampler_instance = described_class.new(0)
        expect(sampler_instance.should_include(operation)).to eq(false)
      end
    end

    describe 'no sample rate or sampler provided' do
      it 'returns true for all operations' do
        sampler_instance = described_class.new(nil)
        expect(sampler_instance.should_include(operation)).to eq(true)
        expect(sampler_instance.should_include(operation)).to eq(true)
      end
    end
  end
end