# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GraphQL::Hive::Sampler do
  let(:sampler_instance) { described_class.new(options) }
  let(:options) { {} }

  describe '#initialize' do
    it 'creates a basic sampler' do
      expect(sampler_instance.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQL::Hive::Sampling::BasicSampler)
    end

    context 'when provided a sampling rate' do
      let(:options) { { collect_usage_sampling_rate: 0.5 } }

      it 'creates a basic sampler' do
        expect(sampler_instance.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQL::Hive::Sampling::BasicSampler)
      end

      context 'using the deprecated field' do
        let(:logger) { instance_double('Logger') }
        let(:options) do
          {
            logger: logger,
            collect_usage_sampling: 1
          }
        end

        before do
          allow(logger).to receive(:warn)
        end

        it 'creates a basic sampler' do
          expect(sampler_instance.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQL::Hive::Sampling::BasicSampler)
        end

        it 'logs a warning' do
          sampler_instance
          expect(logger).to have_received(:warn)
        end
      end
    end

    context 'when provided a sampler' do
      let(:options) { { collect_usage_sampler: proc {} } }

      it 'creates a dynamic sampler' do
        expect(sampler_instance.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQL::Hive::Sampling::DynamicSampler)
      end
    end
  end
end
