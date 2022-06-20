require 'sinatra'
require 'sinatra/json'
require 'rack/contrib'

require_relative 'schema'

# Test query:
#
# query GetPost($input: [PostInput!]!) {
#   post(input: $input, test: TEST1) {
#     title
#     myId: id
#   }
# }


class DemoApp < Sinatra::Base
  use Rack::JSONBodyParser

  post '/graphql' do
    result = Schema.execute(
      params['query'],
      variables: params[:variables],
      operation_name: params[:operationName],
      context: {
        client_name: 'GraphQL Client',
        client_version: '1.0'
      }
    )
    json result
  end
end
