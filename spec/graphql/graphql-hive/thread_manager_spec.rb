require "spec_helper"

RSpec.describe GraphQL::Hive::ThreadManager do
  let(:logger) { instance_double("Logger", warn: nil, error: nil) }
  let(:options) { {logger: logger, buffer_size: 2} }
  let(:queue) { Queue.new }
  let(:sampler) { GraphQL::Hive::Sampler.new(1) }
  let(:thread_manager) { described_class.new(options, queue, sampler) }

  describe "#initialize" do
    it "initializes with the correct instance variables" do
      expect(thread_manager.instance_variable_get(:@options)).to eq(options)
      expect(thread_manager.instance_variable_get(:@queue)).to eq(queue)
      expect(thread_manager.instance_variable_get(:@buffer)).to be_a(GraphQL::Hive::Buffer)
    end
  end

  describe "#start_thread" do
    context "when thread is not alive" do
      it "starts a new thread" do
        expect(Thread).to receive(:new).and_call_original
        thread_manager.start_thread
        expect(thread_manager.instance_variable_get(:@thread)).to be_a(Thread)
      end
    end

    context "when thread is already alive" do
      it "logs a warning and does not start a new thread" do
        thread_manager.start_thread
        expect(logger).to receive(:warn).with("Tried to start operations flushing thread but it was already alive")
        thread_manager.start_thread
      end
    end

    context "when an error occurs in the thread" do
      it "logs the error" do
        mutex = Mutex.new
        condition = ConditionVariable.new

        buffer = thread_manager.instance_variable_get(:@buffer)
        allow(buffer).to receive(:run).and_raise(StandardError.new("Test error"))
        allow(logger).to receive(:error) do |error|
          mutex.synchronize { condition.signal }
        end
        mutex.synchronize do
          thread_manager.start_thread
          condition.wait(mutex)
        end
        expect(logger).to have_received(:error).with(instance_of(StandardError))
      end
    end
  end

  describe "#join_thread" do
    it "closes the queue and joins the thread" do
      thread_manager.start_thread
      expect(queue).to receive(:close)
      expect(thread_manager.instance_variable_get(:@thread)).to receive(:join)
      thread_manager.join_thread
    end
  end
end
