# frozen_string_literal: true

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    # Fetch all users fields, input objects and enums
    class Analyzer < GraphQL::Analysis::AST::Analyzer
      def initialize(query_or_multiplex)
        super
        @used_fields = Set.new
      end

      def on_leave_field(node, _parent, visitor)
        @used_fields.add(visitor.parent_type_definition.graphql_name)
        @used_fields.add([visitor.parent_type_definition.graphql_name, node.name].join('.'))
      end

      def on_leave_argument(node, parent, visitor)
        @used_fields.add([visitor.parent_type_definition.graphql_name, parent.name, node.name].join('.'))

        arg_type = visitor.argument_definition.type.unwrap
        arg_type_kind = visitor.argument_definition.type.unwrap.kind
        if arg_type_kind.input_object?
          @used_fields.add(arg_type.graphql_name)
          arg_type.arguments.each do |arg|
            @used_fields.add([arg_type.graphql_name, arg[0]].join('.'))
          end
        elsif arg_type_kind.enum?
          @used_fields.add([arg_type.graphql_name, node.value.name].join('.'))
        end
      end

      def result
        @used_fields
      end
    end
  end
end
