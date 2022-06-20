# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GraphQL::Hive::Printer' do
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
    The query root of this schema
    """
    type Query {
      """
      Find a post by ID
      """
      post(id: Int!, test: TestEnum!): Post
    }

    enum TestEnum {
      TEST1
      TEST2
      TEST3
    }|)
  end

  let(:query_string) do
    %|
      query GetPost2 {
        post(id: 2, test: TEST1) {
          title
          myId: id
        }
      }
    |
  end

  it 'should print the operation with removed literals, removed aliases and sorted nodes and directives (files, arguments, variables)' do
    query = GraphQL::Query.new(schema, query_string)

    expected_result = %|query GetPost2 {
  post(id: 0, test: TEST1) {
    id
    title
  }
}|

    expect(GraphQL::Hive::Printer.new.print(query.document)).to eq(expected_result)
  end
end
