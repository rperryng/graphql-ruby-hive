## Releasing `graphql-hive` on RubyGems


1. Ensure dependencies are properly installed: `bundle`
1. Ensure the is working as expected: `bundle exec rspec`
1. **Make sure to manually bump the version in `lib/graphql-hive/version.rb`**
1. Build the gem: `gem build graphql-hive`
1. A new file should have been created, ex: `graphql-hive-0.3.0.gem`
1. Then, login to RubyGems: `gem login`
1. And publish the new version: `gem publish <path_to_gem_file>` (ex: `gem publish graphql-hive-0.3.0.gem`)
