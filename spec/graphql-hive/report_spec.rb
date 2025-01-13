require "spec_helper"

RSpec.describe GraphQLHive::Report do
  subject(:report) { described_class.new(client_info: client_info, operations: [operation]) }
  let(:client_info) { ->(context) { {name: "test_client"} } }
  let(:analyzer_result) { double("AnalyzerResult") }
  let(:analyzer) { instance_double(GraphQLHive::Analyzer, result: Set.new(["field1", "field2"])) }
  let(:visitor) { instance_double(GraphQL::Analysis::AST::Visitor) }
  let(:printer) { instance_double(GraphQLHive::Printer) }
  let(:query) do
    double("Query",
      operations: {"TestOperation" => {}},
      context: double("Context"))
  end

  let(:operation) do
    [
      Time.now,
      [query],
      [double("Result", query: query, to_h: {"data" => {}, "errors" => []})],
      100
    ]
  end

  describe "#build" do
    let(:now) { Time.now }
    let(:expected_result) do
      {
        size: 1,
        map: {
          "66afe3e05e74aeab15b481d9ed528728" => {
            fields: ["field1", "field2"],
            operationName: "TestOperation",
            operation: "query TestOperation { field1 field2 }"
          }
        },
        operations: [
          {
            operationMapKey: "66afe3e05e74aeab15b481d9ed528728",
            timestamp: now.to_i,
            execution: {ok: true, duration: 100, errorsTotal: 0},
            metadata: {client: {name: "test_client"}}
          }
        ]
      }
    end
    before do
      Timecop.freeze(now)
      allow(GraphQLHive::Analyzer).to receive(:new).and_return(analyzer)
      allow(GraphQL::Analysis::AST::Visitor).to receive(:new).and_return(visitor)
      allow(visitor).to receive(:visit).and_return(analyzer_result)
      allow(GraphQLHive::Printer).to receive(:new).and_return(printer)
      allow(printer).to receive(:print).and_return("query TestOperation { field1 field2 }")
    end

    after do
      Timecop.return
    end

    it "builds a report with correct structure" do
      expect(report.build).to eq(expected_result)
    end

    context "when there are errors in the result" do
      let(:operation) do
        [
          Time.now,
          [query],
          [double("Result", query: query, to_h: {"errors" => ["Some error"]})],
          100
        ]
      end

      it "counts the errors correctly" do
        result = report.build
        expect(result[:operations].first[:execution][:ok]).to be false
        expect(result[:operations].first[:execution][:errorsTotal]).to eq(1)
      end
    end

    context "with client info" do
      it "includes client metadata in operation record" do
        result = report.build
        expect(result[:operations].first[:metadata][:client]).to eq({name: "test_client"})
      end
    end

    context "without client info" do
      let(:report) { described_class.new(operations: [operation]) }

      it "does not include metadata in operation record" do
        result = report.build
        expect(result[:operations].first).not_to include(:metadata)
      end
    end

    describe "operation mapping" do
      it "creates correct operation map entry" do
        result = report.build
        map_key = result[:operations].first[:operationMapKey]
        expect(result[:map][map_key]).to include(
          fields: ["field1", "field2"],
          operationName: "TestOperation",
          operation: "query TestOperation { field1 field2 }"
        )
      end
    end
  end
end
