# frozen_string_literal: true

require "spec_helper"
require "graphql-hive"

RSpec.describe GraphQL::Hive::Client do
  let(:options) do
    GraphQL::Hive::Configuration.new({
      endpoint: "app.graphql-hive.com",
      port: 443,
      token: "Bearer test-token",
      logger: Logger.new(nil)
    })
  end

  let(:client) { described_class.new(options) }
  let(:body) { {size: 3, map: {}, operations: []} }

  describe "#initialize" do
    it "sets the instance" do
      expect(client.instance_variable_get(:@port)).to eq("443")
      expect(client.instance_variable_get(:@scheme)).to eq("https")
      expect(client.instance_variable_get(:@host)).to eq("app.graphql-hive.com")
      expect(client.instance_variable_get(:@token)).to eq("Bearer test-token")
      expect(client.instance_variable_get(:@use_ssl)).to be true
      expect(client.instance_variable_get(:@logger)).to eq(options.logger)
    end
  end

  describe "#send" do
    let(:http) { instance_double(Net::HTTP) }
    let(:request) { instance_double(Net::HTTP::Post) }
    let(:response) { instance_double(Net::HTTPOK, body: "", code: "200", message: "OK") }

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
      expect(options.logger).to receive(:fatal).with("Failed to send data: Network error")
      expect { client.send(:"/usage", body, :usage) }.not_to raise_error(StandardError, "Network error")
    end

    context "when the response status code is between 400 and 499" do
      let(:response) do
        instance_double(
          Net::HTTPClientError,
          body: '{"errors":[{"path":"test1","message":"Error message 1"},{"path":"test2","message":"Error message 2"}]}',
          code: "400",
          message: "Bad Request"
        )
      end

      before do
        allow(http).to receive(:request).and_return(response)
      end

      it "logs a warning with error details" do
        expect(options.logger).to receive(:warn).with("Unsuccessful response: 400 - Bad Request { path: test1, message: Error message 1 }, { path: test2, message: Error message 2 }")
        client.send(:"/usage", body, :usage)
      end

      context "when the response body is not valid JSON" do
        let(:response) { instance_double(Net::HTTPClientError, body: "Invalid JSON", code: "400", message: "Bad Request") }

        it "logs a warning without error details" do
          expect(options.logger).to receive(:warn).with("Unsuccessful response: 400 - Bad Request Could not parse response from Hive")
          client.send(:"/usage", body, :usage)
        end
      end

      context "when the response body does not contain errors" do
        let(:response) { instance_double(Net::HTTPClientError, body: "{}", code: "401", message: "Unauthorized") }

        it "logs a warning without error details" do
          expect(options.logger).to receive(:warn).with("Unsuccessful response: 401 - Unauthorized ")
          client.send(:"/usage", body, :usage)
        end
      end
    end
  end
end
