# TODO: replace with a `GraphQL::Analysis::AST::Analyzer`
module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class Visitor < GraphQL::Language::Visitor
      def initialize(document)
        super(document)
        @used_fields = []
      end

      attr_reader :used_fields

      def on_field(node, parent)
        
        puts '------'
        puts node.kind if node.respond_to?(:kind)
        puts parent.kind if parent.respond_to?(:kind)
        puts '------'
        @used_fields << make_id([parent.name, node.name])

        super
      end

      private

      def make_id(names)
        names.join('.')
      end

    end
  end
end
