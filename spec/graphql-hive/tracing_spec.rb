require "spec_helper"

RSpec.describe GraphQLHive::Tracing do
  let(:instance) { described_class.instance }
  let(:usage_reporter) { instance_double(GraphQLHive::UsageReporter) }
  let(:configuration) do
    instance_double(
      GraphQLHive::Configuration,
      buffer_size: 100,
      client_info: {name: "test-client"},
      client: double("client"),
      collect_usage_sampling: {rate: 0.5},
      queue_size: 1000,
      logger: Logger.new(nil)
    )
  end

  before do
    allow(GraphQLHive).to receive(:configuration).and_return(configuration)
    allow(GraphQLHive::UsageReporter).to receive(:new).and_return(usage_reporter)
    allow(usage_reporter).to receive(:add_operation)
    allow(usage_reporter).to receive(:start)
    allow(usage_reporter).to receive(:stop)
    instance.configuration = configuration
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
        expect(operation.elapsed_ns).to be_a(Integer)
      end
    end
  end

  describe "#stop" do
    context "when usage reporter is initialized" do
      before { instance.instance_variable_set(:@usage_reporter, usage_reporter) }

      it "calls stop on the usage reporter" do
        instance.stop
        expect(usage_reporter).to have_received(:stop)
      end
    end

    context "when usage reporter is not initialized" do
      before { instance.instance_variable_set(:@usage_reporter, nil) }

      it "does nothing" do
        expect { instance.stop }.not_to raise_error
      end
    end
  end

  describe "#start" do
    before { instance.instance_variable_set(:@usage_reporter, usage_reporter) }

    it "calls start on the usage reporter" do
      instance.start
      expect(usage_reporter).to have_received(:start)
    end
  end

  describe "aliases" do
    it "aliases stop to on_exit" do
      expect(instance.method(:on_exit)).to eq(instance.method(:stop))
    end

    it "aliases start to on_start" do
      expect(instance.method(:on_start)).to eq(instance.method(:start))
    end
  end
end
