require 'sinatra'
require 'sinatra/json'
require 'rack/contrib'

require_relative 'schema'

class DemoApp < Sinatra::Base
  use Rack::JSONBodyParser

  post '/graphql' do
    result = Schema.execute(params['query'], variables: params[:variables], operation_name: params[:operationName])
    json result
  end
end
