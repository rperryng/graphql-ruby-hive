RSpec.describe GraphQLHive::UsageReporter do
  let(:buffer_size) { 10 }
  let(:client) { instance_double("GraphQLHive::Client") }
  let(:sampler) { instance_double("GraphQLHive::Sampler") }
  let(:queue) { instance_double("SizedQueue") }
  let(:logger) { instance_double("Logger") }
  let(:client_info) { ->(ctx) { {name: "test-client"} } }
  let(:thread) { instance_double("Thread", join: nil, alive?: true) }

  subject(:reporter) do
    described_class.new(
      buffer_size: buffer_size,
      client: client,
      sampler: sampler,
      queue: queue,
      logger: logger,
      client_info: client_info
    )
  end

  before do
    allow(Thread).to receive(:new).and_return(thread)
  end

  describe "#add_operation" do
    let(:operation) { ["timestamp", [], [], 100] }

    before do
      allow(queue).to receive(:push)
      allow(queue).to receive(:size).and_return(5)
      allow(queue).to receive(:max).and_return(10)
    end

    it "pushes operation to queue" do
      reporter.add_operation(operation)
      expect(queue).to have_received(:push).with(operation, true)
    end

    context "when queue is full" do
      before do
        allow(queue).to receive(:push).and_raise(ThreadError)
        allow(logger).to receive(:warn).and_yield
      end

      it "logs error" do
        reporter.add_operation(operation)
        expect(logger).to have_received(:warn) do |&block|
          expect(block.call).to eq("SizedQueue is full, discarding operation. Size: 5, Max: 10")
        end
      end
    end
  end

  describe "#stop" do
    before do
      allow(queue).to receive(:close)
      allow(Thread).to receive(:new).and_return(thread)
    end

    it "closes queue and joins thread" do
      reporter.stop
      expect(queue).to have_received(:close)
      expect(thread).to have_received(:join)
    end
  end

  describe "#on_exit" do
    it "is an alias of #stop" do
      expect(reporter.method(:on_exit)).to eq(reporter.method(:stop))
    end
  end

  describe "#start" do
    let(:thread) { instance_double("Thread", alive?: true) }

    before do
      allow(Thread).to receive(:new).and_return(thread)
      allow(logger).to receive(:warn)
    end

    it "starts a new thread" do
      reporter
      expect(Thread).to have_received(:new)
    end

    context "when thread is already alive" do
      it "logs warning" do
        reporter.start
        expect(logger).to have_received(:warn) do |&block|
          expect(block.call).to eq("Usage reporter is already running")
        end
      end
    end
  end

  describe "#on_start" do
    it "is an alias of #start" do
      expect(reporter.method(:on_start)).to eq(reporter.method(:start))
    end
  end
end
