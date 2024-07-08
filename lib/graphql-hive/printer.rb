# frozen_string_literal: true

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    # - removes literals
    # - removes aliases
    # - sort nodes and directives (files, arguments, variables)
    class Printer < GraphQL::Language::Printer
      def print_node(node, indent: '')
        case node
        when Float, Integer
          print_string '0'
        when String
          print_string ''
        else
          super(node, indent: indent)
        end
      end

      # from GraphQL::Language::Printer with sort_by name
      def print_field(field, indent: "")
        print_string(indent)
        if field.alias
          print_string(field.alias)
          print_string(": ")
        end
        print_string(field.name)
        if field.arguments.any?
          print_string("(")
          field.arguments.sort_by(&:name).each_with_index do |a, i|
            print_argument(a)
            print_string(", ") if i < field.arguments.size - 1
          end
          print_string(")")
        end
        print_directives(field.directives)
        print_selections(field.selections, indent: indent)
      end

      def print_directives(directives)
        super(directives.sort_by(&:name))
      end

      # from GraphQL::Language::Printer with sort_by name
      def print_selections(selections, indent: "")
        return if selections.empty?

        print_string(" {\n")
        selections.sort_by.each do |selection|
          print_node(selection, indent: indent + "  ")
          print_string("\n")
        end
        print_string(indent)
        print_string("}")
      end

      # from GraphQL::Language::Printer with sort_by name
      def print_directive(directive)
        print_string("@")
        print_string(directive.name)

        if directive.arguments.any?
          print_string("(")
          directive.arguments.sort_by(&:name).each_with_index do |a, i|
            print_argument(a)
            print_string(", ") if i < directive.arguments.size - 1
          end
          print_string(")")
        end
      end

      # from GraphQL::Language::Printer with sort_by name
      def print_operation_definition(operation_definition, indent: "")
        print_string(indent)
        print_string(operation_definition.operation_type)
        if operation_definition.name
          print_string(" ")
          print_string(operation_definition.name)
        end

        if operation_definition.variables.any?
          print_string("(")
          operation_definition.variables..sort_by(&:name).each_with_index do |v, i|
            print_variable_definition(v)
            print_string(", ") if i < operation_definition.variables.size - 1
          end
          print_string(")")
        end

        print_directives(operation_definition.directives)
        print_selections(operation_definition.selections, indent: indent)
      end
    end
  end
end
