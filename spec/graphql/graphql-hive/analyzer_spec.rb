# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GraphQL::Hive::Analyzer' do
  subject(:used_fields) do
    query = GraphQL::Query.new(schema, query_string)
    analyzer = GraphQL::Hive::Analyzer.new(query)
    visitor = GraphQL::Analysis::AST::Visitor.new(
      query: query,
      analyzers: [analyzer]
    )

    visitor.visit
    analyzer.used_fields.to_a
  end

  let(:schema) do
    GraphQL::Schema.from_definition(%|
      type Query {
        project(selector: ProjectSelectorInput!): Project
        projectsByType(type: ProjectType!): [Project!]!
        projects(filter: FilterInput): [Project!]!
      }

      type Mutation {
        deleteProject(selector: ProjectSelectorInput!): DeleteProjectPayload!
      }

      input ProjectSelectorInput {
        organization: ID!
        project: ID!
      }

      input FilterInput {
        type: ProjectType
        pagination: PaginationInput
        order: [ProjectOrderByInput!]
      }

      input PaginationInput {
        limit: Int
        offset: Int
      }

      input ProjectOrderByInput {
        field: String!
        direction: OrderDirection
      }

      enum OrderDirection {
        ASC
        DESC
      }

      type ProjectSelector {
        organization: ID!
        project: ID!
      }

      type DeleteProjectPayload {
        selector: ProjectSelector!
        deletedProject: Project!
      }

      type Project {
        id: ID!
        cleanId: ID!
        name: String!
        type: ProjectType!
        buildUrl: String
        validationUrl: String
      }

      enum ProjectType {
        FEDERATION
        STITCHING
        SINGLE
        CUSTOM
      }
    |)
  end

  let(:query_string) do
    %|
      mutation deleteProject($selector: ProjectSelectorInput!) {
        deleteProject(selector: $selector) {
          selector {
            organization
            project
          }

          deletedProject {
            id
            cleanId
            name
            type
          }
        }
      }
    |
  end

  it 'collects used fields and arguments' do
    expect(used_fields).to include(
      'DeleteProjectPayload',
      'DeleteProjectPayload.selector',
      'Mutation',
      'Mutation.deleteProject',
      'Mutation.deleteProject.selector',
      'Project',
      'Project.cleanId',
      'Project.id',
      'Project.name',
      'Project.type',
      'ProjectSelector',
      'ProjectSelector.organization',
      'ProjectSelector.project'
    )
    expect(used_fields).not_to include(
      'Project.buildUrl',
      'Project.validationUrl'
    )
  end

  it 'collects used input object fields' do
    expect(used_fields).to include(
      'ProjectSelectorInput',
      'ProjectSelectorInput.organization',
      'ProjectSelectorInput.project'
    )
  end

  context 'with enum value in argument' do
    let(:query_string) do
      %|
      query getProjects($type: ProjectType!) {
        projectsByType(type: $type) {
          id
        }
      }
    |
    end

    it 'collects all values of that enum type' do
      expect(used_fields).to include(
        'ProjectType.FEDERATION',
        'ProjectType.STITCHING',
        'ProjectType.SINGLE',
        'ProjectType.CUSTOM'
      )
    end
  end

  context 'with enum value hardcoded into the query' do
    let(:query_string) do
      %|
      query getProjects {
        projectsByType(type: FEDERATION) {
          id
        }
      }
    |
    end

    it 'collects used enumn values' do
      expect(used_fields).to include(
        'ProjectType.FEDERATION'
      )
      expect(used_fields).not_to include(
        'ProjectType.STITCHING',
        'ProjectType.SINGLE',
        'ProjectType.CUSTOM'
      )
    end
  end

  context 'with only some input object fields used' do
    let(:query_string) do
      %|
      query getProjects($limit: Int!, $type: ProjectType!) {
        projects(filter: { pagination: { limit: $limit }, type: $type }) {
          id
        }
      }
    |
    end

    it 'collects fields of specified input objects' do
      expect(used_fields).to include(
        'FilterInput',
        'FilterInput.pagination',
        'FilterInput.type',
        'PaginationInput',
        'PaginationInput.limit',
        'Query.projects.filter'
      )

      expect(used_fields).not_to include(
        'FilterInput.order',
        'PaginationInput.offset'
      )
    end
  end

  context 'with query containining both input object variable as well as explicit input object fields' do
    let(:query_string) do
      %|
      query getProjects($type: ProjectType!, $pagination: PaginationInput) {
        projects(filter: { pagination: $pagination, type: $type }) {
          id
        }
      }
    |
    end

    it 'collects all fields of input object variable, but only specific fields for the other input object type' do
      expect(used_fields).to include(
        'PaginationInput',
        'PaginationInput.limit',
        'PaginationInput.offset',
        'FilterInput.type',
        'FilterInput.pagination'
      )

      expect(used_fields).not_to include(
        'FilterInput.order'
      )
    end
  end

  context 'with query containing enum value in nested input object' do
    let(:query_string) do
      %|
      query getProjects($type: ProjectType!, $limit: Int) {
        projects(filter: {
          pagination: {
            limit: $limit
          },
          type: $type,
          order: {
            field: "test",
            direction: ASC,
          }
        }) {
          id
        }
      }
    |
    end

    it 'collects the enum value' do
      expect(used_fields).to include(
        'OrderDirection.ASC'
      )

      expect(used_fields).not_to include(
        'OrderDirection.DESC'
      )
    end
  end
end
