module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    # - removes literals
    # - removes aliases
    # - sort nodes and directives (files, arguments, variables)
    class Printer < GraphQL::Language::Printer

      def print_node(node, indent: "")
        case node
          when Float, Integer
            '0'
          when  String
            ''
          else
            super(node, indent: indent)
          end
      end

      def print_field(field, indent: "")
        out = "#{indent}".dup
        out << "#{field.name}"
        out << "(#{field.arguments.sort_by { |a| a.name }.map { |a| print_argument(a) }.join(", ")})" if field.arguments.any?
        out << print_directives(field.directives)
        out << print_selections(field.selections, indent: indent)
        out
      end

      def print_directives(directives)
        super(directives.sort_by { |d| d.name })
      end

      def print_selections(selections, indent: "")
        super(selections.sort_by { |s| s.name }, indent: indent)
      end

      def print_directive(directive)
        out = "@#{directive.name}".dup

        if directive.arguments.any?
          out << "(#{directive.arguments.sort_by { |a| a.name }.map { |a| print_argument(a) }.join(", ")})"
        end

        out
      end

      def print_operation_definition(operation_definition, indent: "")
        out = "#{indent}#{operation_definition.operation_type}".dup
        out << " #{operation_definition.name}" if operation_definition.name

        if operation_definition.variables.any?
          out << "(#{operation_definition.variables.sort_by { |v| v.name }.map { |v| print_variable_definition(v) }.join(", ")})"
        end

        out << print_directives(operation_definition.directives)
        out << print_selections(operation_definition.selections, indent: indent)
        out
      end

    end
  end
end
