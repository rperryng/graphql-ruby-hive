require "spec_helper"

RSpec.describe GraphQLHive::Tracing do
  subject(:instance) { described_class.new(usage_reporter: usage_reporter) }
  let(:usage_reporter) { instance_double(GraphQLHive::UsageReporter) }
  let(:configuration) do
    instance_double(
      GraphQLHive::Configuration,
      buffer_size: 100,
      client: double("client"),
      client_info: {name: "test-client"},
      collect_usage_sampling: {rate: 0.5},
      logger: Logger.new(nil),
      queue_size: 1000,
      usage_reporter: usage_reporter
    )
  end

  before do
    allow(GraphQLHive).to receive(:configuration).and_return(configuration)
    allow(GraphQLHive::UsageReporter).to receive(:new).and_return(usage_reporter)
    allow(usage_reporter).to receive(:add_operation)
    allow(usage_reporter).to receive(:start)
    allow(usage_reporter).to receive(:stop)
  end

  after do
    Singleton.__init__(described_class)
  end

  describe "#trace" do
    let(:queries) { ["query { user { id } }"] }
    let(:results) { [{"data" => {"user" => {"id" => 1}}}] }
    let(:timestamp) { Time.now.to_i * 1000 }

    before { Timecop.freeze }
    after { Timecop.return }

    it "yields and returns the results" do
      expect(instance.trace(queries: queries) { results }).to eq(results)
    end

    it "records operation with correct data" do
      instance.trace(queries: queries) { results }

      expect(usage_reporter).to have_received(:add_operation) do |operation|
        expect(operation.timestamp).to eq(timestamp)
        expect(operation.queries).to eq(queries)
        expect(operation.results).to eq(results.map(&:to_h))
        expect(operation.duration).to be_a(Integer)
      end
    end
  end
end
