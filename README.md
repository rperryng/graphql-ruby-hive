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


<br/>

----

<br/>


# Getting started


## 0. Get your Hive token

If you are using Hive as a service, please refer to our documentation: https://docs.graphql-hive.com/features/tokens.

## 1. Install the `graphql-hive` gem

```
gem install graphql-hive
```

<br/>

## 2. Configure `GraphQLHive` in your Schema

Add `GraphQLHive` **at the end** of your schema definition:

```ruby
class Schema < GraphQL::Schema
  query QueryType

  trace_with(
      GraphQLHive::Tracer,
      {
        token: '<YOUR_TOKEN>',
        reporting: {
          author: ENV['GITHUB_USER'],
          commit: ENV['GITHUB_COMMIT']
        },
      }
  )
end

```

The `reporting` configuration is required to push your GraphQL Schema to the Hive registry.
Doing so will help better detect breaking changes and more upcoming features.
If you only want to use the operations monitoring, replace the `reporting` option with the following `report_schema: false`.

<br/>

## 3. (Optional) Configure Lifecycle Hooks

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
  GraphQLHive.instance.start
end
```

### `on_exit`

If your GraphQL API process is shut down non-gracefully but has a shutdown hook
to call into, call `on_worker_exit`.

`puma` example:

```ruby
# config/puma.rb

on_worker_shutdown do
  GraphQLHive.instance.on_exit
end
```

<br />

**You are all set! 🚀**

When deploying or starting up your GraphQL API, `graphql-hive` will immediately:
- publish the schema to the Hive registry
- forward the operations metrics to Hive


<br/>

## 4. See how your GraphQL API is operating

You should now see operations information (RPM, error rate, queries performed) on your [GraphQL Hive dashboard](https://app.graphql-hive.com/):

<p align="center">
  <img src="operations-dashboard.png" width="500" alt="GraphQL Hive" />
</p>


<br/>


## 5. Going further: use the Hive Github app

Stay on top of your GraphQL Schema changes by installing the Hive Github Application and enabling Slack notifications about breaking changes:

https://docs.graphql-hive.com/features/integrations#github

<br/>

----

<br/>


# Configuration

You will find below the complete list of options of `GraphQLHive`:

```ruby
class MySchema < GraphQL::Schema
  trace_with(
    GraphQLHive::Trace,
    {
      # Token is the only required configuration value.
      token: 'YOUR-REGISTRY-TOKEN',
      #
      # The following are optional configuration values.
      #
      # Enable/disable Hive Client.
      enabled: true,
      # Verbose logs.
      debug: false,
      # A custom logger.
      logger: MyLogger.new,
      # Endpoint and port of the Hive API. Change this if you are using a self-hosted Hive instance.
      endpoint: 'app.graphql-hive.com',
      port: 80,
      # Number of operations sent to Hive in a batch (AFTER sampling).
      buffer_size: 50,
      # Size of the queue used to send operations to the buffer before sampling.
      queue_size: 1000,
      # Report usage to Hive.
      collect_usage: true,
      # Usage sampling configurations.
      collect_usage_sampling: {
        # % of operations recorded.
        sample_rate: 0.5,
        # Custom sampler to assign custom sampling rates.
        sampler: proc { |context| context.operation_name.includes?('someQuery') 1 : 0.5 },
        # Sample every distinct operation at least once.
        at_least_once: true,
        # Assign custom keys to distinguish between distinct operations.
        key_generator: proc { |context| context.operation_name }
      },
      # Publish schema to Hive.
      report_schema: true,
      # Mandatory if `report_schema: true`.
      reporting: {
        # Mandatory members of `reporting`.
        author: 'Author of the latest change',
        commit: 'git sha or any identifier',
        # Optional members of `reporting`.
        service_name: '',
        service_url: '',
      },

      # Pass an optional proc to client_info to help identify the client (ex: Apollo web app) that performed the query.
      client_info: proc { |context|
        { name: context.client_name, version: context.client_version }
      }
    }
  )

  # ...

end
```

See default options for the optional parameters [here](https://github.com/rperryng/graphql-ruby-hive/blob/master/lib/graphql-hive.rb#L31-L41).

<br/>

> [!Important]
> `buffer_size` and `queue_size` will affect memory consumption.
>
> `buffer_size` is the number of operations sent to Hive in a batch after operations have been sampled.
> `queue_size` is the size of the queue used to send operations to the buffer before sampling.
> Adjust these values according to your application's memory constraints and throughput.
> High throughput applications will need a larger `queue_size`.
