# frozen_string_literal: true

require "spec_helper"
require "graphql-hive"

RSpec.describe GraphQL::Hive::Client do
  let(:logger) { instance_double(Logger, fatal: nil, debug: nil) }
  let(:token) { "Bearer test-token" }
  let(:client) do
    described_class.new(token: token, logger: logger)
  end
  let(:body) { {size: 3, map: {}, operations: []} }

  describe "#initialize" do
    it "sets the instance" do
      expect(client.instance_variable_get(:@port)).to eq("443")
      expect(client.instance_variable_get(:@use_ssl)).to eq(true)
      expect(client.instance_variable_get(:@scheme)).to eq("https")
      expect(client.instance_variable_get(:@endpoint)).to eq("app.graphql-hive.com")
      expect(client.instance_variable_get(:@token)).to eq(token)
      expect(client.instance_variable_get(:@logger)).to be(logger)
    end
  end

  describe "#send" do
    let(:http) { instance_double(Net::HTTP) }
    let(:request) { instance_double(Net::HTTP::Post) }
    let(:response) { instance_double(Net::HTTPOK, body: "", code: "200") }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(Net::HTTP::Post).to receive(:new).and_return(request)

      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(response)

      allow(request).to receive(:[]=) # request['header-name'] = 'header-value'
      allow(request).to receive(:body=)
    end

    it "sets up the HTTP session" do
      expect(Net::HTTP).to receive(:new).with("app.graphql-hive.com", 443).and_return(http)
      expect(http).to receive(:use_ssl=).with(true)
      expect(http).to receive(:read_timeout=).with(2)

      client.send(:"/usage", body, :usage)
    end

    it "creates the request with the correct headers and body" do
      expect(Net::HTTP::Post).to receive(:new).with(:"/usage").and_return(request)
      expect(request).to receive(:[]=).with("Authorization", "Bearer test-token")
      expect(request).to receive(:[]=).with("X-Usage-API-Version", "2")
      expect(request).to receive(:[]=).with("content-type", "application/json")
      expect(request).to receive(:[]=).with("User-Agent", "Hive@#{Graphql::Hive::VERSION}")
      expect(request).to receive(:[]=).with("graphql-client-name", "Hive Ruby Client")
      expect(request).to receive(:[]=).with("graphql-client-version", Graphql::Hive::VERSION)
      expect(request).to receive(:body=).with(JSON.generate(body))

      client.send(:"/usage", body, :usage)
    end

    it "executes the request" do
      expect(http).to receive(:request).with(request).and_return(response)
      client.send(:"/usage", body, :usage)
    end

    it "logs a fatal error when an exception is raised" do
      allow(http).to receive(:request).and_raise(StandardError.new("Network error"))
      expect(logger).to receive(:fatal).with("Failed to send data: Network error")
      expect { client.send(:"/usage", body, :usage) }.not_to raise_error(StandardError, "Network error")
    end
  end
end
