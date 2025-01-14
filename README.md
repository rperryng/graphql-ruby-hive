# GraphQL Hive: `graphql-ruby` integration
[![CI Suite](https://github.com/charlypoly/graphql-ruby-hive/actions/workflows/ci.yml/badge.svg)](https://github.com/charlypoly/graphql-ruby-hive/actions)
[![Gem Version](https://badge.fury.io/rb/graphql-hive.svg)](https://rubygems.org/gems/graphql-hive)

<p align="center">
  <img src="cover.png" width="500" alt="GraphQL Hive" />
</p>

[GraphQL Hive](https://graphql-hive.com/) provides all the tools to get visibility of your GraphQL architecture at all stages, from standalone APIs to composed schemas (Federation, Stitching):
- **Schema Registry** with custom breaking changes detection
- **Monitoring** of RPM, latency, error rate, and more
- **Integrations** with your favorite tools (Slack, Github Actions, and more)

----

# Getting started

## 0. Get your Hive token

If you are using Hive as a service, please refer to our documentation: https://docs.graphql-hive.com/features/tokens.

## 1. Install the `graphql-hive` gem

```
gem install graphql-hive
```

## 2. Configure `GraphQLHive` in your Schema

Add `GraphQLHive` **at the end** of your schema definition:

```ruby
# app/initializers/graphql_hive.rb
GraphQLHive.configure do |config|
  config.token = '<YOUR_TOKEN>'
end

# schema.rb
class Schema < GraphQL::Schema
  query QueryType

  trace_with(GraphQLHive::Tracer)
end

```

## 3. (Optional) Report your schema to Hive

If you want to report your schema to Hive, you can do so by calling the `report_schema_to_hive` method. You can call this method in the initializer file or in CI.

```ruby
# app/initializers/graphql_hive.rb
GraphQLHive.report_schema_to_hive(
  schema: Schema,
  options: {
    # Required
    author: ENV['GITHUB_USER'],
    commit: ENV['GITHUB_COMMIT'],
    # Optional
    service: ENV['GRAPHQL_HIVE_SERVICE_NAME'],
    url: ENV['GRAPHQL_HIVE_SERVICE_URL'],
    force: ENV['GRAPHQL_HIVE_FORCE_REPORT']
  }
)
```

## 4. (Optional) Configure Lifecycle Hooks

Calling these hooks are situational - it's likely that you may not need to call
them at all!

### `start`

Call this hook if you are running `GraphQLHive` in a process that `fork`s
itself.

example: `puma` web server running in (["clustered
mode"](https://github.com/puma/puma/tree/6d8b728b42a61bcf3c1e4c698c9165a45e6071e8#clustered-mode))

```ruby
# config/puma.rb
preload_app!

on_worker_boot do
  GraphQLHive.start
end
```

### `on_exit`

If your GraphQL API process is shut down non-gracefully but has a shutdown hook
to call into, call `on_worker_exit`.

`puma` example:

```ruby
# config/puma.rb

on_worker_shutdown do
  GraphQLHive.stop
end
```

**You are all set! 🚀**

When deploying or starting up your GraphQL API, `graphql-hive` will immediately:
- publish the schema to the Hive registry
- forward the operations metrics to Hive

## 5. See how your GraphQL API is operating

You should now see operations information (RPM, error rate, queries performed) on your [GraphQL Hive dashboard](https://app.graphql-hive.com/):

<p align="center">
  <img src="operations-dashboard.png" width="500" alt="GraphQL Hive" />
</p>

## 6. Going further: use the Hive Github app

Stay on top of your GraphQL Schema changes by installing the Hive Github Application and enabling Slack notifications about breaking changes:

https://docs.graphql-hive.com/features/integrations#github

----

# Configuration

You will find below the complete list of options of `GraphQLHive`:

```ruby
# app/initializers/graphql_hive.rb
GraphQLHive.configure do |config|
  # Token is the only required configuration value.
  config.token = 'YOUR-REGISTRY-TOKEN'
  
  # The following are optional configuration values.
  
  # Enable/disable Hive Client.
  config.enabled = true
  # Verbose logs.
  config.debug = false
  # A custom logger.
  config.logger = MyLogger.new
  # Endpoint and port of the Hive API. Change this if you are using a self-hosted Hive instance.
  config.endpoint = 'app.graphql-hive.com'
  config.port = 80
  # Number of operations sent to Hive in a batch (AFTER sampling).
  config.buffer_size = 50
  # Size of the queue used to send operations to the buffer before sampling.
  config.queue_size = 1000
  # Report usage to Hive.
  config.collect_usage = true
  # Usage sampling configurations.
  config.collect_usage_sampling = {
    # % of operations recorded.
    sample_rate: 0.5,
    # Custom sampler to assign custom sampling rates.
    sampler: proc { |context| context.operation_name.includes?('someQuery') 1 : 0.5 },
    # Sample every distinct operation at least once.
    at_least_once: true,
    # Assign custom keys to distinguish between distinct operations.
    key_generator: proc { |context| context.operation_name }
  }

  # Pass an optional proc to client_info to help identify the client (ex: Apollo web app) that performed the query.
  config.client_info = proc { |context|
    { name: context.client_name, version: context.client_version }
  }
end
```

See default options for the optional parameters [here](https://github.com/rperryng/graphql-ruby-hive/blob/master/lib/graphql-hive.rb#L31-L41).

> [!Important]
> `buffer_size` and `queue_size` will affect memory consumption.
>
> `buffer_size` is the number of operations sent to Hive in a batch after operations have been sampled.
> `queue_size` is the size of the queue used to send operations to the buffer before sampling.
> Adjust these values according to your application's memory constraints and throughput.
> High throughput applications will need a larger `queue_size`.
