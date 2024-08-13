# frozen_string_literal: true

require 'spec_helper'
require 'ostruct'

RSpec.describe GraphQL::Hive::Sampler::BasicSampler do
  let(:sampler_instance) { described_class.new(sampling_rate, at_least_once_sampling) }
  let(:sampling_rate) { 0 }
  let(:at_least_once_sampling) { nil }

  let(:schema) { GraphQL::Schema.from_definition('type Query { test: String }') }
  let(:timestamp) { 1_720_705_946_333 }
  let(:queries) { [GraphQL::Query.new(schema, query: '{ test }')] }
  let(:results) { [OpenStruct.new(query: OpenStruct.new(context: { header: 'value' }))] }
  let(:duration) { 100 }

  let(:operation) { [timestamp, queries, results, duration] }

  describe '#initialize' do
    it 'sets the sample rate' do
      sampler_instance = described_class.new(0.5)
      expect(sampler_instance.instance_variable_get(:@sample_rate)).to eq(0.5)
    end
  end

  describe '#sample?' do
    it 'follows the sample rate for all operations' do
      expect(sampler_instance.sample?(operation)).to eq(false)
    end

    context 'with at least once sampling' do
      let(:at_least_once_sampling) { true }

      it 'returns true for the first operation, then follows the sample rate for remaining operations' do
        expect(sampler_instance.sample?(operation)).to eq(true)
        expect(sampler_instance.sample?(operation)).to eq(false)
      end

      context 'when provided a custom key generator' do
        let(:at_least_once_sampling) { proc { |_sample_context| 'same_key' } }

        it 'tracks operations by their custom keys' do
          expect(sampler_instance.sample?(operation)).to eq(true)

          queries = [GraphQL::Query.new(schema, query: '{ something_else }')]
          different_operation = [timestamp, queries, results, duration]

          expect(sampler_instance.sample?(different_operation)).to eq(false)
        end
      end
    end
  end
end
