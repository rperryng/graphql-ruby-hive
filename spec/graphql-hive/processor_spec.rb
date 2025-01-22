require "spec_helper"

RSpec.describe GraphQLHive::Processor do
  let(:buffer_size) { 2 }
  let(:client) { instance_double("GraphQLHive::Client") }
  let(:sampler) { instance_double("GraphQLHive::Sampler") }
  let(:queue) { instance_double("Thread::SizedQueue") }
  let(:logger) { instance_double("Logger") }
  let(:query) do
    double("Query",
      operations: {"TestOperation" => {}},
      context: double("Context"))
  end
  let(:operation) do
    GraphQLHive::Operation.new(
      Time.now,
      [query],
      [double("Result", query: query, to_h: {"data" => {}, "errors" => []})],
      100
    )
  end
  let(:analyzer_result) { double("AnalyzerResult") }
  let(:analyzer) { instance_double(GraphQLHive::Analyzer, result: Set.new(["field1", "field2"])) }
  let(:visitor) { instance_double(GraphQL::Analysis::AST::Visitor) }
  let(:printer) { instance_double(GraphQLHive::Printer) }
  let(:processor) do
    described_class.new(
      queue: queue,
      logger: logger,
      buffer_size: buffer_size,
      client: client,
      sampler: sampler
    )
  end
  let(:now) { Time.now }
  let(:expected_report) do
    {
      map: {
        "66afe3e05e74aeab15b481d9ed528728" => {
          fields: ["field1", "field2"],
          operation: "query TestOperation { field1 field2 }",
          operationName: "TestOperation"
        }
      },
      operations: [
        {
          execution: {duration: 100, errorsTotal: 0, ok: true},
          operationMapKey: "66afe3e05e74aeab15b481d9ed528728",
          timestamp: now.to_i
        },
        {
          execution: {duration: 100, errorsTotal: 0, ok: true},
          operationMapKey: "66afe3e05e74aeab15b481d9ed528728",
          timestamp: now.to_i
        }
      ],
      size: 2
    }
  end

  before do
    Timecop.freeze(now)
    allow(queue).to receive(:pop).and_return(
      operation,
      operation,
      nil
    )
    allow(logger).to receive(:debug)
    allow(logger).to receive(:error)
    allow(client).to receive(:send)
    allow(sampler).to receive(:sample?).and_return(true)
    allow(GraphQLHive::Analyzer).to receive(:new).and_return(analyzer)
    allow(GraphQL::Analysis::AST::Visitor).to receive(:new).and_return(visitor)
    allow(visitor).to receive(:visit).and_return(analyzer_result)
    allow(GraphQLHive::Printer).to receive(:new).and_return(printer)
    allow(printer).to receive(:print).and_return("query TestOperation { field1 field2 }")
    allow(queue).to receive(:closed?).and_return(false, false, true)
  end

  describe "#process_queue" do
    context "when buffer becomes full" do
      it "flushes the buffer" do
        expect(processor.instance_variable_get(:@buffer)).to be_empty
        Timeout.timeout(1) { processor.process_queue }
        expect(client).to have_received(:send).with(
          :"/usage",
          expected_report,
          :usage
        )
        expect(processor.instance_variable_get(:@buffer)).to be_empty
      end
    end

    context "when an error occurs" do
      before do
        allow(sampler).to receive(:sample?).and_raise(StandardError.new("Test error"))
      end

      it "rescues the error, logs it, and empties the buffer" do
        expect(processor.instance_variable_get(:@buffer)).to be_empty
        Timeout.timeout(1) { processor.process_queue }
        expect(logger).to have_received(:error).with("Failed to process operation: Test error").twice
        expect(client).not_to have_received(:send)
        expect(processor.instance_variable_get(:@buffer)).to be_empty
      end
    end
  end
end
