# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Works with `Schema.trace_with` you will need to update your schema to use this method. There is an example in app.rb

### Removed
- BREAKING: No longer works with `Schema.use` as this is deprecated in graphql-ruby.
- BREAKING: Namespace conflict with `GraphQL`. Everything is now named `GraphQLHive`.
- BREAKING: Support for Ruby 3.1 as it will reach EOL in March 2025.

### Changed
- Refactored graphql-hive.rb to us a configuration class
- Refactored graphql-hive.rb to use a separate class for sending the schema to the registry
- Updated all dependencies to latest versions
- Added super_diff and timecop for testing
- Added Report class to build report
- Added Processor to run the loop
- Broke UsageReporter into smaller classes
- Add `start` and `stop` methods for clarity that they don't accept a block
- Only start reporter if it is needed
- Added tests that test integration with a real GraphQL Schema
- Update spec folder nesting to match lib
