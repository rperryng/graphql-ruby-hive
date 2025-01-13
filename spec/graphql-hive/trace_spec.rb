require "spec_helper"

RSpec.describe GraphQLHive::Trace do
  let(:schema_class) do
    Class.new(GraphQL::Schema) do
      query = Class.new(GraphQL::Schema::Object) do
        field :test, String, null: true
        def test
          "test response"
        end

        graphql_name "TestQuery"
      end

      query(query)
      trace_with(
        GraphQLHive::Trace,
        token: "test-token",
        logger: Logger.new(nil)
      )
    end
  end

  let(:query_string) { "{ test }" }
  let(:hive_instance) { GraphQLHive::Tracing.instance }

  describe "#execute_multiplex" do
    context "when collect_usage is enabled" do
      before do
        allow(hive_instance).to receive(:trace).and_yield
      end

      it "calls trace with the queries" do
        expect(hive_instance).to receive(:trace).with(
          queries: [have_attributes(query_string: query_string)]
        )

        schema_class.execute(query_string)
      end

      it "executes the query and returns the correct result" do
        allow(hive_instance).to receive(:trace).and_yield

        result = schema_class.execute(query_string)

        expect(result["data"]["test"]).to eq("test response")
      end
    end

    context "when collect_usage is disabled" do
      let(:schema_class) do
        Class.new(GraphQL::Schema) do
          query = Class.new(GraphQL::Schema::Object) do
            field :test, String, null: true
            def test
              "test response"
            end

            graphql_name "TestQuery"
          end

          query(query)
          trace_with(
            GraphQLHive::Trace,
            token: "test-token",
            logger: Logger.new(nil),
            collect_usage: false
          )
        end
      end

      it "does not call trace" do
        expect(hive_instance).not_to receive(:trace)

        result = schema_class.execute(query_string)
        expect(result["data"]["test"]).to eq("test response")
      end
    end
  end
end
