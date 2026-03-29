# AshPrefixedId

An [Ash](https://ash-hq.org/) extension for working with prefixed IDs (e.g. `user_CWzLBdFy2f1XhrtesFferY`).

Inspired by [Stripe's object IDs](https://dev.to/stripe/designing-apis-for-humans-object-ids-3o5a), this library lets you use human-readable, prefixed identifiers while storing standard UUIDs in the database.

## Installation

Add `ash_prefixed_id` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_prefixed_id, "~> 0.1.0"}
  ]
end
```

## Usage

Add the `AshPrefixedId` extension to your resource and configure a prefix:

```elixir
defmodule App.Blog.Post do
  use Ash.Resource,
    domain: App.Blog,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPrefixedId]

  prefixed_id do
    prefix "post"
  end

  actions do
    defaults [:read, :destroy, create: [:title], update: [:title]]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end
end
```

```elixir
Post
|> Ash.Changeset.for_create(:create, %{title: "Hello world"})
|> Ash.create!()
#=> %Post{id: "post_CWzLBdFy2f1XhrtesFferY"}
```

### Foreign Keys

`belongs_to` relationships automatically get the correct prefixed ID type:

```elixir
relationships do
  belongs_to :post, App.Blog.Post
  # post_id is auto-created as App.Blog.Post.ObjectId
end
```

### AnyPrefixedId

Register `AnyPrefixedId` as a custom type to accept prefixed IDs anywhere `:uuid` is used:

```elixir
config :ash, custom_types: [uuid: AshPrefixedId.AnyPrefixedId]
```

### PostgreSQL UUIDv7

Enable server-side UUIDv7 generation with `AshPrefixedId.PostgresExtension`:

```elixir
defmodule MyApp.Repo do
  use AshPostgres.Repo, otp_app: :my_app

  def installed_extensions do
    ["uuid-ossp", "citext", AshPrefixedId.PostgresExtension]
  end
end
```

Then in your resource:

```elixir
prefixed_id do
  prefix "post"
  migration_default? true
end
```

### Utility Functions

```elixir
# Decode a prefixed ID to a UUID string
AshPrefixedId.decode_object_id("user_CWzLBdFy2f1XhrtesFferY")
#=> {:ok, "5d446d08-df6a-404d-a1e5-decc78429b3d"}

# Convert to raw UUID binary (for SQL fragments)
AshPrefixedId.to_uuid!("user_CWzLBdFy2f1XhrtesFferY")

# Convert UUID back to prefixed ID
AshPrefixedId.to_prefixed_id(uuid_binary, "user")

# Find which resource a prefixed ID belongs to
AshPrefixedId.find_resource_for_id(domains, "user_CWzLBdFy2f1XhrtesFferY")

# Detect duplicate prefixes across domains
AshPrefixedId.find_duplicate_prefixes(domains)
```

For more detailed information, read the `AshPrefixedId` moduledoc.

## Acknowledgments

This project is a fork of [ash_object_ids](https://github.com/drtheuns/ash_object_ids) by [Randall Theuns](https://github.com/drtheuns). The original work laid the foundation for prefixed ID support in Ash.

## License

MIT — see [LICENSE](LICENSE) for details.
