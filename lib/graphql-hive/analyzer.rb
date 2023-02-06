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

        arguments = visitor.query.arguments_for(node, visitor.field_definition)
        # If there was an error when preparing this argument object,
        # then this might be an error or something:
        if arguments.respond_to?(:argument_values)
          extract_arguments(arguments.argument_values, visitor.field_definition)
        end
      end

      attr_reader :used_fields

      def result
        @used_fields
      end

      private

      def extract_arguments(argument_values, argument_parent_definition = nil)
        argument_values.each_pair do |_argument_name, argument|
          type = argument.definition.type

          if type.unwrap.kind.enum?
            @used_fields.add(type.unwrap.graphql_name)
            @used_fields.add([type.unwrap.graphql_name, argument.value].join('.'))
          elsif type.unwrap.kind.input_object?
            @used_fields.add(type.unwrap.graphql_name)

            if argument_parent_definition.type.unwrap.kind.object?
              # visiting field argument
              @used_fields.add([
                argument_parent_definition.owner.graphql_name,
                argument_parent_definition.graphql_name,
                argument.definition.graphql_name
              ].join('.'))
            elsif argument_parent_definition.type.unwrap.kind.input_object?
              # visiting input object field
              @used_fields.add([
                argument_parent_definition.type.unwrap.graphql_name,
                argument.definition.graphql_name
              ].join('.'))
            end

            # TODO: nested input objects are missing
            extract_arguments(argument.value.arguments.argument_values, argument.definition)
          elsif argument.definition.type.list?
            argument
              .value
              .select { |value| value.respond_to?(:arguments) }
              .each do |value|
                extract_arguments(value.arguments.argument_values)
              end
          end
        end
      end
    end
  end
end
