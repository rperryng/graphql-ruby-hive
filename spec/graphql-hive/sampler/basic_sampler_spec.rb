# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraphQLHive::Sampling::BasicSampler do
  let(:sampler_instance) do
    described_class.new(
      options: {
        sample_rate: sample_rate,
        at_least_once: at_least_once,
        key_generator: key_generator
      }
    )
  end
  let(:sample_rate) { 0 }
  let(:at_least_once) { false }
  let(:key_generator) { nil }

  describe "#initialize" do
    it "sets the sample rate" do
      expect(sampler_instance.instance_variable_get(:@sample_rate)).to eq(0)
    end

    context "when the sample_rate is a string" do
      let(:sample_rate) { "0.1" }
      it "converts the sample rate to a float" do
        expect(sampler_instance.instance_variable_get(:@sample_rate)).to eq(0.1)
      end
    end

    context "when the sample_rate is nil" do
      let(:sample_rate) { nil }

      it "sets the sample rate to 1" do
        expect(sampler_instance.instance_variable_get(:@sample_rate)).to eq(1)
      end
    end
  end

  describe "#sample?" do
    let(:schema) { GraphQL::Schema.from_definition("type Query { test: String }") }
    let(:timestamp) { 1_720_705_946_333 }
    let(:queries) { [GraphQL::Query.new(schema, query: "{ test }", context: {header: "value"})] }
    let(:results) { [GraphQL::Query::Result.new(query: queries.first, values: {"data" => {"test" => "test"}})] }
    let(:duration) { 100 }
    let(:operation) { [timestamp, queries, results, duration] }

    it "follows the sample rate for all operations" do
      expect(sampler_instance.sample?(operation)).to eq(false)
    end

    context "with at least once sampling" do
      let(:at_least_once) { true }

      it "returns true for the first operation, then follows the sample rate for remaining operations" do
        expect(sampler_instance.sample?(operation)).to eq(true)
        expect(sampler_instance.sample?(operation)).to eq(false)
      end

      context "when provided a custom key generator" do
        let(:key_generator) { proc { |_sample_context| "same_key" } }

        it "tracks operations by their custom keys" do
          expect(sampler_instance.sample?(operation)).to eq(true)

          queries = [GraphQL::Query.new(schema, query: "{ something_else }")]
          different_operation = [timestamp, queries, results, duration]

          expect(sampler_instance.sample?(different_operation)).to eq(false)
        end
      end
    end
  end
end
