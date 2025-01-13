# frozen_string_literal: true

RSpec.describe GraphQLHive do
  describe "VERSION" do
    it "is defined" do
      expect(GraphQLHive::VERSION).not_to be_nil
    end

    it "follows semantic versioning format" do
      expect(GraphQLHive::VERSION).to match(/^\d+\.\d+\.\d+$/)
    end
  end

  describe ".gem_version" do
    it "returns a Gem::Version instance" do
      expect(GraphQLHive.gem_version).to be_a(Gem::Version)
    end

    it "matches VERSION constant" do
      expect(GraphQLHive.gem_version.to_s).to eq(GraphQLHive::VERSION)
    end
  end
end
