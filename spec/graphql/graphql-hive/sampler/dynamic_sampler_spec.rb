# frozen_string_literal: true

require 'spec_helper'
require 'ostruct'

RSpec.describe GraphQL::Hive::Sampling::DynamicSampler do
  let(:sampler_instance) { described_class.new(sampler, at_least_once_sampling) }
  let(:sampler) { proc { |_sample_context| 0 } }
  let(:at_least_once_sampling) do
    {
      enabled: false
    }
  end

  describe '#initialize' do
    it 'sets the sampler and tracked operations hash' do
      expect(sampler_instance.instance_variable_get(:@sampler)).to eq(sampler)
      expect(sampler_instance.instance_variable_get(:@tracked_operations)).to eq({})
    end
  end

  describe '#sample?' do
    let(:schema) { GraphQL::Schema.from_definition('type Query { test: String }') }
    let(:timestamp) { 1_720_705_946_333 }
    let(:queries) { [GraphQL::Query.new(schema, query: '{ test }')] }
    let(:results) { [GraphQL::Query::Result.new(query: queries.first, values: { 'data' => { 'test' => 'test' } })] }
    let(:duration) { 100 }
    let(:operation) { [timestamp, queries, results, duration] }

    it 'follows the sampler for all operations' do
      expect(sampler_instance.sample?(operation)).to eq(false)
    end

    context 'when the sampler does not return a number' do
      let(:sampler) { proc { |_sample_context| 'not a number' } }

      it 'raises an error' do
        expect { sampler_instance.sample?(operation) }.to raise_error(ArgumentError)
      end
    end

    context 'with at least once sampling' do
      let(:at_least_once_sampling) do
        {
          enabled: true
        }
      end

      it 'returns true for the first operation, then follows the sampler for remaining operations' do
        expect(sampler_instance.sample?(operation)).to eq(true)
        expect(sampler_instance.sample?(operation)).to eq(false)
      end

      context 'when provided a custom key generator' do
        let(:at_least_once_sampling) do
          {
            enabled: true,
            keygen: proc { |_sample_context| 'same_key' }
          }
        end

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
