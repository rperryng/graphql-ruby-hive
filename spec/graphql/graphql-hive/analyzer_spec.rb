# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GraphQL::Hive::Analyzer' do
  let(:schema) do
    GraphQL::Schema.from_definition(%|
    """
    A blog post
    """
    type Post {
      id: ID!
      title: String!
      truncatedPreview: String!
    }

    """
    Query Post arguments
    """
    input PostInput {
      id: ID!
    }

    """
    The query root of this schema
    """
    type Query {
      """
      Find a post by ID
      """
      post(input: [PostInput!]!, test: TestEnum!): Post
    }

    enum TestEnum {
      TEST1
      TEST2
      TEST3
    }|)
  end

  let(:query_string) do
    %|
      query GetPost2($input: [PostInput!]!) {
        post(input: $input, test: TEST1) {
          title

          myId: id
        }
      }
    |
  end

  it 'should return all used fields, input type and enum values' do
    query = GraphQL::Query.new(schema, query_string)

    puts query.document

    analyzer = GraphQL::Hive::Analyzer.new(query)
    visitor = GraphQL::Analysis::AST::Visitor.new(
      query: query,
      analyzers: [analyzer]
    )

    visitor.visit

    expect(analyzer.used_fields.to_a).to eq(['Query.post.input', 'PostInput', 'PostInput.id', 'Query.post.test',
                                             'TestEnum.TEST1', 'Post', 'Post.title', 'Post.id', 'Query', 'Query.post'])
  end
end
