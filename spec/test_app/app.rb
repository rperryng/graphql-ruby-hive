require "graphql"
require "graphql-hive"
require "sinatra"

module Types
  class PostType < GraphQL::Schema::Object
    description "A blog post"
    field :id, ID, null: false
    field :title, String, null: false
    field :truncated_preview, String, null: false
  end
end

class QueryType < GraphQL::Schema::Object
  description "The query root of this schema"

  field :post, Types::PostType, "Find a post by ID" do
    argument :id, ID, required: true
  end

  def post(id:)
    {id: 1, title: "GraphQL Hive with `graphql-ruby`"}
  end
end

class Schema < GraphQL::Schema
  query QueryType

  trace_with(GraphQLHive::Trace)
end

GraphQLHive.configure do |config|
  config.enabled = true
  config.token = "fake-token"
  config.report_schema = false
  config.collect_usage_sampling = {
    sample_rate: 1
  }
  config.buffer_size = 5
  config.schema = self
end

class TestApp < Sinatra::Base
  post "/graphql" do
    request.body.rewind
    params = JSON.parse(request.body.read)
    result = Schema.execute(
      query: params["query"],
      variables: params["variables"],
      operation_name: params["operationName"],
      context: {
        client_name: "GraphQL Client",
        client_version: "1.0"
      }
    )
    content_type :json
    JSON.dump(result)
  rescue => e
    status 500
    JSON.dump("errors" => [e.message])
  end
end
