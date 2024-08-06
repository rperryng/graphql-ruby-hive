require 'spec_helper'

RSpec.describe GraphQL::Hive::Sampler do
  let(:subject) { described_class.instance }

  describe '#initialize' do
    it 'sets the sample rate if provided a sample rate' do
      sampler_instance = described_class.new(0)
      expect(sampler_instance.instance_variable_get(:@sample_rate)).to eq(0)
      expect(sampler_instance.instance_variable_get(:@sampler)).to eq(nil)
      expect(sampler_instance.instance_variable_get(:@tracked_operations)).to eq(nil)
    end

    it 'sets the sampler and tracked operations hash if provided a sampler' do
      mock_sampler = Proc.new { |operation| true }
      sampler_instance = described_class.new(mock_sampler)
      expect(sampler_instance.instance_variable_get(:@sample_rate)).to eq(1)
      expect(sampler_instance.instance_variable_get(:@sampler)).to eq(mock_sampler)
      expect(sampler_instance.instance_variable_get(:@tracked_operations)).to eq({})
    end
  end
end