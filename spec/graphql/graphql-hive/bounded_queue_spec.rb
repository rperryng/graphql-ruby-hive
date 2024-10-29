# frozen_string_literal: true

require "spec_helper"
require "graphql-hive"

RSpec.describe GraphQL::Hive::BoundedQueue do
  subject(:queue) { GraphQL::Hive::BoundedQueue.new(bound: 2, logger: logger) }

  let(:logger) { instance_double("Logger") }

  before do
    allow(logger).to receive(:error)
  end

  it "should be a subclass of Thread::Queue" do
    expect(GraphQL::Hive::BoundedQueue.superclass).to eq(Thread::Queue)
  end

  it "should be able to push items up to size" do
    queue.push("one")
    queue.push("two")

    expect(queue.size).to eq(2)
  end

  it "should discard items and log when full" do
    queue.push("one")
    queue.push("two")
    queue.push("three")
    queue.push("four")

    expect(queue.size).to eq(2)
    expect(logger).to have_received(:error).with("BoundedQueue is full, discarding operation").twice
  end

  it "allows pushes after pops" do
    queue.push("one")
    queue.push("two")

    queue.push("invalid")
    expect(queue.size).to eq(2)

    queue.pop
    queue.push("three")
    expect(queue.size).to eq(2)
  end

  it "should be thsead-safe and discard items when full" do
    threads = []
    10.times do |i|
      threads << Thread.new do
        queue.push(i)
      end
    end

    threads.each(&:join)

    expect(queue.size).to eq(2)
    expect(logger).to have_received(:error).with("BoundedQueue is full, discarding operation").exactly(8).times
  end

  it "should be able to push after pop in multi-threaded environment" do
    threads = []
    perform_operations = [:push, :push, :pop, :push, :push, :push, :push]

    perform_operations.each do |operation|
      threads << Thread.new do
        queue.push("operation") if operation == :push
        queue.pop if operation == :pop
      end
    end

    threads.each(&:join)

    expect(queue.size).to eq(2)
    expect(logger).to have_received(:error).with("BoundedQueue is full, discarding operation").exactly(3).times
  end
end
