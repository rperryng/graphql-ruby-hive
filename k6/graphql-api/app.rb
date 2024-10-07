require "sinatra"
require "sinatra/json"
require "rack/contrib"

require_relative "schema"

class DemoApp < Sinatra::Base
  use Rack::JSONBodyParser

  get "/" do
    status 200
  end

  post "/graphql" do
    result = Schema.execute(
      params["query"],
      variables: params[:variables],
      operation_name: params[:operationName],
      context: {
        client_name: "GraphQL Client",
        client_version: "1.0"
      }
    )
    json result
  end
end
