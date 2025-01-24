# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraphQLHive::Sampler do
  let(:sampler_instance) do
    described_class.build(
      options: sampling_options
    )
  end
  let(:sampling_options) { nil }

  describe "#initialize" do
    it "creates a basic sampler" do
      expect(sampler_instance).to be_an_instance_of(GraphQLHive::Sampling::BasicSampler)
    end

    context "when provided a sampling rate" do
      let(:sampling_options) { {sample_rate: 0.5} }

      it "creates a basic sampler" do
        expect(sampler_instance).to be_an_instance_of(GraphQLHive::Sampling::BasicSampler)
      end

      context "using the deprecated field" do
        let(:sampling_options) { 1 }

        it "creates a basic sampler" do
          expect(sampler_instance).to be_an_instance_of(GraphQLHive::Sampling::BasicSampler)
        end
      end
    end

    context "when provided a sampler" do
      let(:sampling_options) { {sampler: proc {}} }

      it "creates a dynamic sampler" do
        expect(sampler_instance).to be_an_instance_of(GraphQLHive::Sampling::DynamicSampler)
      end
    end
  end
end
