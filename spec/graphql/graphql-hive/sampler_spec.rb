# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraphQLHive::Sampler do
  let(:sampler_instance) { described_class.new(sampling_options: sampling_options, logger: logger) }
  let(:sampling_options) { nil }
  let(:logger) { instance_double("Logger") }

  describe "#initialize" do
    it "creates a basic sampler" do
      expect(sampler_instance.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQLHive::Sampling::BasicSampler)
    end

    context "when provided a sampling rate" do
      let(:sampling_options) { {sample_rate: 0.5} }

      it "creates a basic sampler" do
        expect(sampler_instance.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQLHive::Sampling::BasicSampler)
      end

      context "using the deprecated field" do
        let(:sampling_options) { 1 }

        before do
          allow(logger).to receive(:warn)
        end

        it "creates a basic sampler" do
          expect(sampler_instance.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQLHive::Sampling::BasicSampler)
        end

        it "logs a warning" do
          sampler_instance
          expect(logger).to have_received(:warn)
        end
      end
    end

    context "when provided a sampler" do
      let(:sampling_options) { {sampler: proc {}} }

      it "creates a dynamic sampler" do
        expect(sampler_instance.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQLHive::Sampling::DynamicSampler)
      end
    end
  end
end
