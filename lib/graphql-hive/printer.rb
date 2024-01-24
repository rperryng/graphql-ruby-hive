# frozen_string_literal: true

require 'debug'

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    # - removes literals
    # - removes aliases
    # - sort nodes and directives (files, arguments, variables)
    class Printer < GraphQL::Language::Printer
      def print_node(node, indent: '')
        case node
        when Float, Integer
          '0'
        when String
          ''
        else
          super(node, indent: indent)
        end
      end

      # rubocop:disable Style/RedundantInterpolation
      def print_field(field, indent: '')
        out = "#{indent}".dup
        out << "#{field.name}"
        out << "(#{field.arguments.sort_by(&:name).map { |a| print_argument(a) }.join(', ')})" if field.arguments.any?
        out << print_directives(field.directives)
        out << print_selections(field.selections, indent: indent)
        out
      end
      # rubocop:enable Style/RedundantInterpolation

      def print_directives(directives)
        return '' if directives.empty?

        super(directives.sort_by(&:name))
      end

      def print_selections(selections, indent: '')
        return '' if selections.empty?

        sorted_nodes = selections.sort_by do |s|
          next s.name if s.respond_to?(:name)
          next s.type.name if s.respond_to?(:type)

          raise "don't know how to sort selection node: #{s.inspect}"
        end
        super(sorted_nodes, indent: indent)
      end

      def print_directive(directive)
        out = "@#{directive.name}".dup

        if directive.arguments.any?
          out << "(#{directive.arguments.sort_by(&:name).map { |a| print_argument(a) }.join(', ')})"
        end

        out
      end

      def print_operation_definition(operation_definition, indent: '')
        out = "#{indent}#{operation_definition.operation_type}".dup
        out << " #{operation_definition.name}" if operation_definition.name

        # rubocop:disable Layout/LineLength
        if operation_definition.variables.any?
          out << "(#{operation_definition.variables.sort_by(&:name).map { |v| print_variable_definition(v) }.join(', ')})"
        end
        # rubocop:enable Layout/LineLength

        out << print_directives(operation_definition.directives)
        out << print_selections(operation_definition.selections, indent: indent)
        out
      end
    end
  end
end
