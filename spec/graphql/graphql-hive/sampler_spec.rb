require 'spec_helper'

RSpec.describe GraphQL::Hive::Sampler do
  let(:subject) { described_class.instance }

  describe '#initialize' do
    it 'sets the sampler and tracked operations hash, if provided a sampler' do
      mock_sampler = Proc.new { |sample_context| 1 }
      sampler_instance = described_class.new(mock_sampler)
      expect(sampler_instance.instance_variable_get(:@sample_rate)).to eq(nil)
      expect(sampler_instance.instance_variable_get(:@sampler)).to eq(mock_sampler)
      expect(sampler_instance.instance_variable_get(:@tracked_operations)).to eq({})
    end

    it 'sets the sample rate, if provided a sample rate' do
      sampler_instance = described_class.new(0)
      expect(sampler_instance.instance_variable_get(:@sample_rate)).to eq(0)
      expect(sampler_instance.instance_variable_get(:@sampler)).to eq(nil)
      expect(sampler_instance.instance_variable_get(:@tracked_operations)).to eq(nil)
    end

    it 'sets the sample rate to 1, if no sample rate or sampler is provided' do
      sampler_instance = described_class.new(nil)
      expect(sampler_instance.instance_variable_get(:@sample_rate)).to eq(1)
      expect(sampler_instance.instance_variable_get(:@sampler)).to eq(nil)
      expect(sampler_instance.instance_variable_get(:@tracked_operations)).to eq(nil)
    end
  end

  describe '#should_include' do
    it 'returns true for the first operation and follows the sampler for the remaining operations, if provided a sampler' do
      mock_sampler = Proc.new { |sample_context| 0 }
      sampler_instance = described_class.new(mock_sampler)
      expect(sampler_instance.should_include('operation')).to eq(true)
      expect(sampler_instance.should_include('operation')).to eq(false)
    end

    it 'follows the sample rate for all operations, if provided a sample rate' do
      sampler_instance = described_class.new(0)
      expect(sampler_instance.should_include('operation')).to eq(false)
    end

    it 'returns true for all operations, if no sample rate or sampler is provided' do
      sampler_instance = described_class.new(nil)
      expect(sampler_instance.should_include('operation')).to eq(true)
      expect(sampler_instance.should_include('operation')).to eq(true)
    end
  end
end