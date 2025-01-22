# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraphQLHive::Operation do
  let(:timestamp) { Time.now }
  let(:queries) { ["query { user { id name } }"] }
  let(:results) { [{"data" => {"user" => {"id" => "1", "name" => "Test User"}}}] }
  let(:duration) { 100 }

  subject(:operation) do
    described_class.new(
      timestamp,
      queries,
      results,
      duration
    )
  end

  describe "initialization" do
    it "creates an operation with the given attributes" do
      expect(operation.timestamp).to eq(timestamp)
      expect(operation.queries).to eq(queries)
      expect(operation.results).to eq(results)
      expect(operation.duration).to eq(duration)
    end
  end

  describe "attributes" do
    it "allows reading the timestamp" do
      expect(operation.timestamp).to be_a(Time)
    end

    it "allows reading the queries" do
      expect(operation.queries).to be_an(Array)
    end

    it "allows reading the results" do
      expect(operation.results).to be_an(Array)
    end

    it "allows reading the duration" do
      expect(operation.duration).to be_a(Numeric)
    end
  end

  describe "immutability" do
    it "freezes the operation instance" do
      expect(operation).to be_frozen
    end
  end
end
