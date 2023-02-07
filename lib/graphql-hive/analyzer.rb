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
        @used_fields.add(make_id(visitor.parent_type_definition.graphql_name, node.name))
      end

      # Visitor also calls 'on_enter_argument' when visiting input object fields in arguments
      def on_enter_argument(node, parent, visitor)
        arg_type = visitor.argument_definition.type.unwrap
        @used_fields.add(arg_type.graphql_name)

        # collect field argument path
        # input object fields won't have a "parent.name" method available
        if parent.respond_to?(:name)
          @used_fields.add(make_id(visitor.parent_type_definition.graphql_name, parent.name, node.name))
        end

        if arg_type.kind.input_object?
          collect_input_object_fields(node, arg_type)
        elsif arg_type.kind.enum?
          collect_enum_values(node, arg_type)
        end
      end

      attr_reader :used_fields

      def result
        @used_fields
      end

      private

      def collect_input_object_fields(node, input_type)
        case node.value
        when GraphQL::Language::Nodes::VariableIdentifier
          input_type.all_argument_definitions.map(&:graphql_name).each do |n|
            @used_fields.add(make_id(input_type.graphql_name, n))
          end
        when Array
          node.value.flat_map(&:arguments).map(&:name).each do |n|
            @used_fields.add(make_id(input_type.graphql_name, n))
          end
        else
          node.value.arguments.map(&:name).each do |n|
            @used_fields.add(make_id(input_type.graphql_name, n))
          end
        end
      end

      def collect_enum_values(node, enum_type)
        case node.value
        when GraphQL::Language::Nodes::VariableIdentifier
          enum_type.values.values.map(&:graphql_name).each do |n|
            @used_fields.add(make_id(enum_type.graphql_name, n))
          end
        when Array
          node.value.map(&:name).each do |n|
            @used_fields.add(make_id(enum_type.graphql_name, n))
          end
        else
          @used_fields.add(make_id(enum_type.graphql_name, node.value.name))
        end
      end

      def make_id(*tokens)
        tokens.join('.')
      end
    end
  end
end
