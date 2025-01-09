require "spec_helper"
require_relative "test_app/app"
require "rack/test"

RSpec.describe TestApp do
  include Rack::Test::Methods

  def app
    TestApp
  end

  wait_for_reporting = lambda do |timeout, req_count|
    Timeout.timeout(timeout) do
      loop do
        if WebMock::RequestRegistry.instance.requested_signatures.hash.size >= req_count
          break
        end
        sleep 0.1
      end
    end
  rescue Timeout::Error
    puts "Timed out waiting for reporting to finish."
  end

  let(:usage_request_count) { 4 }
  let(:query) do
    <<~GQL
      query GetPost($id: ID!){
        post(id: $id) {
          title
          id
        }
      }
    GQL
  end

  let(:request_body) do
    {
      query: query,
      variables: {id: 1},
      operationName: "GetPost"
    }.to_json
  end

  let(:expected_request_body) do
    {
      "size" => 5,
      "map" => {
        "92c5ca035dc4ee9a7347ffb368cd9ffb" => {
          "fields" => ["Query", "Query.post", "ID", "Query.post.id", "Post", "Post.title", "Post.id"],
          "operationName" => "GetPost",
          "operation" => "query GetPost($id: ID!) {\n  post(id: $id) {\n    id\n    title\n  }\n}"
        }
      },
      "operations" => Array.new(5) {
        {
          "operationMapKey" => "92c5ca035dc4ee9a7347ffb368cd9ffb",
          "timestamp" => be_a(Integer),
          "execution" => {"ok" => true, "duration" => be_a(Integer), "errorsTotal" => 0}
        }
      }
    }
  end

  after do
    GraphQLHive::Tracing.instance.stop
  end

  it("posts data to hive", :aggregate_failures, :vcr) do
    VCR.use_cassette(
      "graphql-hive-integration",
      allow_unused_http_interactions: false
    ) do
      20.times do
        post "/graphql", request_body, "CONTENT_TYPE" => "application/json"

        expect(last_response).to be_ok
        expect(JSON.parse(last_response.body)).to(
          match(
            "data" => {"post" => {"id" => "1", "title" => "GraphQL Hive with `graphql-ruby`"}}
          )
        )
      end
    end

    # NOTE: Reporting happens in a background thread. We give the background
    # thread 1 second to finish reporting before moving on.
    wait_for_reporting.call(1, usage_request_count)

    WebMock::RequestRegistry.instance.requested_signatures.each do |request_signature|
      request_body = JSON.parse(request_signature.body)
      expect(request_body).to include(expected_request_body)
    end

    expect(WebMock).to have_requested(:post, "https://app.graphql-hive.com/usage")
      .with(
        body: anything,
        headers: {
          "Accept" => "*/*",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Authorization" => "fake-token",
          "Content-Type" => "application/json",
          "Graphql-Client-Name" => "Hive Ruby Client",
          "Graphql-Client-Version" => /[\d+\..]/,
          "User-Agent" => /Hive@[\d+\..]/,
          "X-Usage-Api-Version" => "2"
        }
      ).times(usage_request_count)
  end
end
