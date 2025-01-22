# frozen_string_literal: true

RSpec.describe GraphQLHive::UsageReporter do
  let(:buffer_size) { 10 }
  let(:client) { instance_double("GraphQLHive::Client") }
  let(:sampler) { instance_double("GraphQLHive::Sampler") }
  let(:queue) { SizedQueue.new(10) }
  let(:logger) { instance_double("Logger", info: nil, warn: nil, error: nil, debug: nil) }
  let(:processor) { instance_double("GraphQLHive::Processor", process_queue: nil) }

  subject(:reporter) do
    described_class.new(
      queue: queue,
      logger: logger,
      processor: processor
    )
  end

  before do
    allow(GraphQLHive::Processor).to receive(:new).and_return(processor)
  end

  describe "#add_operation" do
    let(:operation) { ["timestamp", [], [], 100] }

    context "when reporter is running normally" do
      it "pushes operation to queue" do
        expect { reporter.add_operation(operation) }.not_to raise_error
      end
    end

    context "when queue is full" do
      before do
        buffer_size.times { queue.push(operation) }
      end

      it "logs error" do
        reporter.add_operation(operation)
        expect(logger).to have_received(:error).with(
          "Queue full (size: 10/10), discarding operation"
        )
      end
    end

    context "when reporter is stopping" do
      before do
        queue.close
      end

      it "discards the operation" do
        reporter.add_operation(operation)
        expect(queue).to be_empty
      end
    end

    context "when queue is closed" do
      before do
        queue.close
      end

      it "logs error" do
        reporter.add_operation(operation)
        expect(queue).to be_empty
        expect(logger).to have_received(:warn).with("Queue closed, discarding operation")
      end
    end
  end

  describe "#start" do
    let(:processing_thread) { instance_double(Thread, :alive? => true, :name => nil, :abort_on_exception => nil, :[]= => nil) }
    let(:monitor_thread) { instance_double(Thread, alive?: true, name: nil, abort_on_exception: nil) }

    before do
      allow(Thread).to receive(:new).and_return(processing_thread, monitor_thread)
    end

    it "creates processing and monitoring threads" do
      reporter.start
      expect(Thread).to have_received(:new).twice
    end

    context "when already running" do
      before do
        reporter.instance_variable_set(:@running, true)
        reporter.instance_variable_set(:@processor_thread, processing_thread)
      end

      it "logs warning and does not create new threads" do
        reporter.start
        expect(logger).to have_received(:warn).with("Already running")
        expect(Thread).not_to have_received(:new)
      end
    end
  end

  describe "#stop" do
    let(:processing_thread) { instance_double(Thread, alive?: true, join: nil, kill: nil) }
    let(:monitor_thread) { instance_double(Thread, alive?: true, kill: nil) }

    before do
      reporter.instance_variable_set(:@running, true)
      reporter.instance_variable_set(:@processor_thread, processing_thread)
      reporter.instance_variable_set(:@monitor_thread, monitor_thread)
      allow(monitor_thread).to receive(:join).and_return(nil)
      allow(processing_thread).to receive(:join).and_return(nil)
      reporter.start
    end

    it "stops both threads and closes queue" do
      reporter.stop
      expect(monitor_thread).to have_received(:kill)
      expect(processing_thread).to have_received(:join)
      expect(queue.closed?).to be true
    end

    context "when processing thread does not stop gracefully" do
      before do
        allow(processing_thread).to receive(:join).and_return(nil)
        allow(monitor_thread).to receive(:join).and_return(nil)
      end

      it "forces thread to stop" do
        reporter.stop
        expect(processing_thread).to have_received(:join)
        expect(logger).to have_received(:error).with("Force stopping processor thread")
      end
    end

    context "when no threads are running" do
      before do
        allow(processing_thread).to receive(:alive?).and_return(false)
        allow(monitor_thread).to receive(:alive?).and_return(false)
        allow(monitor_thread).to receive(:join).and_return(nil)
        allow(processing_thread).to receive(:join).and_return(nil)
        reporter.instance_variable_set(:@running, false)
      end

      it "does nothing" do
        reporter.stop
        expect(monitor_thread).not_to have_received(:join)
        expect(processing_thread).not_to have_received(:join)
        expect(queue.closed?).to be false
      end
    end
  end

  describe "aliases" do
    it "aliases #on_start to #start" do
      expect(reporter.method(:on_start)).to eq(reporter.method(:start))
    end

    it "aliases #on_exit to #stop" do
      expect(reporter.method(:on_exit)).to eq(reporter.method(:stop))
    end
  end
end
