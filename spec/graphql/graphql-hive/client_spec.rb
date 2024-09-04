# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GraphQL::Hive::Client do
  let(:options) do
    {
      endpoint: 'app.graphql-hive.com',
      port: 443,
      token: 'Bearer test-token',
      logger: Logger.new(nil)
    }
  end

  let(:client) { described_class.new(options) }
  let(:body) { { size: 3, map: {}, operations: [] } }

  describe '#initialize' do
    it 'sets the instance' do
        expect(client.instance_variable_get(:@options)).to eq(options)
    end
  end

  describe "#send" do
    let(:http) { instance_double(Net::HTTP) }
    let(:request) { instance_double(Net::HTTP::Post) }
    let(:response) { instance_double(Net::HTTPOK, body: '', code: '200') }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(Net::HTTP::Post).to receive(:new).and_return(request)

      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(response)

      allow(request).to receive(:[]=) # request['header-name'] = 'header-value'
      allow(request).to receive(:body=)
    end

    context "when the path is '/usage'" do
      it "sets the Authorization and X-Usage-API-Version headers" do
        expect(request).to receive(:[]=).with('Authorization', 'Bearer test-token')
        expect(request).to receive(:[]=).with('X-Usage-API-Version', '2')
        
        client.send('/usage', body, :usage)
      end
    end

    context "when the path is not '/usage'" do
      it "sets the x-api-token header" do
        expect(request).to receive(:[]=).with('x-api-token', 'Bearer test-token')

        client.send('/registry', body, :'report-schema')
      end
    end

    context "when an exception is raised" do
      it "logs a fatal error" do
        allow(http).to receive(:request).and_raise(StandardError.new("Network error"))
        expect(options[:logger]).to receive(:fatal).with("Failed to send data: Network error")

        client.send('/usage', body, :usage)
      end
    end
  end
end
