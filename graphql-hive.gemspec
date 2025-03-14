# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "graphql-hive/version"

Gem::Specification.new do |spec|
  spec.name = "graphql-hive"
  spec.version = Graphql::Hive::VERSION
  spec.authors = ["Charly POLY"]
  spec.email = ["cpoly55@gmail.com"]

  spec.summary = '"GraphQL Hive integration for `graphql-ruby`"'
  spec.description = '"Monitor operations, inspect your queries and publish your GraphQL schema with GraphQL Hive"'
  spec.homepage = "https://docs.graphql-hive.com/specs/integrations"
  spec.license = "MIT"

  spec.metadata = {"rubygems_mfa_required" => "true"}

  spec.required_ruby_version = Gem::Requirement.new(">= 2.6.0")

  spec.require_paths = ["lib"]
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end

  spec.add_dependency "graphql", ">= 2.3", "< 3"
end
