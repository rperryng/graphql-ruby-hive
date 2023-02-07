# frozen_string_literal: true

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    # Fetch all users fields, input objects and enums
    class Analyzer < GraphQL::Analysis::AST::Analyzer
      def initialize(query_or_multiplex)
        super
        @used_fields = Set.new
      end

      def on_enter_field(node, _parent, visitor)
        @used_fields.add(visitor.parent_type_definition.graphql_name)
        @used_fields.add([visitor.parent_type_definition.graphql_name, node.name].join('.'))
      end

      # Visitor also calls 'on_enter_argument' when visiting explicit input object fields
      def on_enter_argument(node, parent, visitor)
        is_variable = node.value.is_a?(GraphQL::Language::Nodes::VariableIdentifier)
        arg_type = visitor.argument_definition.type.unwrap
        @used_fields.add(arg_type.graphql_name)

        # collect argument path
        # input object fields won't have a "parent.name" method available
        if parent.respond_to?(:name)
          @used_fields.add([visitor.parent_type_definition.graphql_name, parent.name, node.name].join('.'))
        end

        # collect used input object fields
        if arg_type.kind.input_object?
          if is_variable
            arg_type.all_argument_definitions.map(&:graphql_name).each do |n|
              @used_fields.add([arg_type.graphql_name, n].join('.'))
            end
          else
            node.value.arguments.map(&:name).each do |n|
              @used_fields.add([arg_type.graphql_name, n].join('.'))
            end
          end
        end

        # collect used enum values
        if arg_type.kind.enum?
          if is_variable
            arg_type.values.values.map(&:graphql_name).each do |n|
              @used_fields.add([arg_type.graphql_name, n].join('.'))
            end
          else
            @used_fields.add([arg_type.graphql_name, node.value.name].join('.'))
          end
        end
      end

      attr_reader :used_fields

      def result
        @used_fields
      end
    end
  end
end
