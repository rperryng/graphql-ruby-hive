require 'graphql'
require 'graphql-hive'

module Types
  class PostType < GraphQL::Schema::Object
    description "A blog post"
    field :id, ID, null: false
    field :title, String, null: false
    # fields should be queried in camel-case (this will be `truncatedPreview`)
    field :truncated_preview, String, null: false
  end
end


class Types::PostInput < GraphQL::Schema::InputObject
  description "Query Post arguments"
  argument :id, ID, required: true
end

class Types::TestEnum < GraphQL::Schema::Enum
  value "TEST1"
  value "TEST2"
  value "TEST3"
end


class QueryType < GraphQL::Schema::Object
  description "The query root of this schema"

  # First describe the field signature:
  field :post, Types::PostType, "Find a post by ID" do
    argument :input, [Types::PostInput]
    argument :test, Types::TestEnum
  end

  # Then provide an implementation:
  def post(input:, test:)
    { id: 1, title: 'GraphQL Hive with `graphql-ruby`', truncated_preview: "Monitor operations, inspect your queries and publish your GraphQL schema with GraphQL Hive" }
  end
end

class Schema < GraphQL::Schema
  use(GraphQL::Hive, { token: 'xxx-xxx-xxx', debug: true })

  query QueryType
end
