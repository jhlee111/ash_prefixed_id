defmodule AshPrefixedId do
  @moduledoc """
  An extension for working with prefixed IDs.

  Prefixed IDs are identifiers that are prefixed with the resource they identify.
  A more detailed explanation can be found in the ["Designing APIs for
  humans"](https://dev.to/stripe/designing-apis-for-humans-object-ids-3o5a) blog post.

  This library provides an implementation for Ash:

      defmodule App.Blog.Post do
        use Ash.Resource,
          domain: App.Blog,
          data_layer: Ash.DataLayer.AshPostgres,
          extensions: [AshPrefixedId]

        prefixed_id do
          prefix "p"
        end

        attributes do
          uuid_primary_key(:id)
          # ... other attributes
        end
      end

  `AshPrefixedId` replaces the `:id` primary key with a prefixed ID (prefixed by "p").
  The underlying UUID implementation will be used, so it works with both UUID
  and UUIDv7. The IDs are stored as regular UUIDs in the database. Externally,
  the UUIDs are encoded as "{prefix}_{base58(uuid)}".

  Each resource will have a generated `<resource>.ObjectId` module which is the
  `Ash.Type` for that ID. Foreign key attributes for `belongs_to` relationships
  are automatically created with the correct ObjectId type:

      relationships do
        belongs_to :post, App.Blog.Post
        # post_id attribute is auto-created as App.Blog.Post.ObjectId
      end

  ## Working with IDs: the Ash boundary

  Inside Ash you only ever deal with **prefixed IDs** — the raw UUID never
  surfaces. Cast inputs, action results, and `belongs_to` foreign keys are all
  prefixed. You therefore rarely need the conversion helpers in this module;
  they exist for the **boundaries** of your system:

    * Validating *external* input (HTTP params, request bodies, file contents)
      before it enters Ash — use the non-bang `to_uuid/1` / `to_uuid_string/1`
      and handle `{:error, :invalid_prefixed_id}`.
    * Building raw SQL fragments, or talking to non-Ash code that needs the raw
      UUID — use the bang `to_uuid!/1` / `to_uuid_string!/1`. IDs that come from
      inside Ash are always valid, so let it crash.

  Bang is the default inside Ash; reach for the non-bang variants only when an
  invalid value is genuinely expected (i.e. at an external boundary).

  If you find yourself sniffing the ID format (e.g. `String.starts_with?(id,
  "user_")`) or handling "both raw UUID and prefixed" forms, that is a sign a
  raw UUID has leaked across a boundary — fix the caller, don't normalize
  everywhere. To accept both prefixed IDs and raw UUIDs transparently for a
  `:uuid` field, register `AshPrefixedId.AnyPrefixedId` as a custom type instead
  of converting by hand.
  """

  alias AshPrefixedId.Type

  @transformers (if Code.ensure_loaded?(AshPostgres.DataLayer) do
                   [
                     AshPrefixedId.Transformers.BelongsToAttribute,
                     AshPrefixedId.Transformers.MigrationDefaults
                   ]
                 else
                   [
                     AshPrefixedId.Transformers.BelongsToAttribute
                   ]
                 end)

  @persisters [
    AshPrefixedId.Persisters.DefineType
  ]

  @prefixed_id %Spark.Dsl.Section{
    name: :prefixed_id,
    describe: "Use prefixed ID for identifier of a resource",
    examples: [
      """
      prefixed_id do
        prefix "u"
      end
      """
    ],
    schema: [
      prefix: [
        type: :string,
        doc: "The prefix to use for the given resource",
        required: true
      ],
      migration_default?: [
        type: :boolean,
        doc:
          "When true, adds `uuid_generate_v7()` as the PostgreSQL migration default for the primary key. Requires `AshPrefixedId.PostgresExtension` to be installed.",
        default: false
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@prefixed_id],
    transformers: @transformers,
    persisters: @persisters

  @doc """
  Decodes a prefixed ID into the raw 16-byte UUID binary, returning a tagged tuple.

  This is the non-bang variant: reach for it only when validating **external**
  input (HTTP params, request bodies, file contents) at a boundary, where a bad
  value is expected and you want to handle it gracefully. Inside Ash you only
  ever see valid prefixed IDs, so prefer `to_uuid!/1` there.

  ## Examples

      iex> to_uuid("user_CWzLBdFy2f1XhrtesFferY")
      {:ok, <<93, 68, 109, 8, ...>>}

      iex> to_uuid("not a prefixed id")
      {:error, :invalid_prefixed_id}
  """
  @spec to_uuid(binary()) :: {:ok, binary()} | {:error, :invalid_prefixed_id}
  def to_uuid(prefixed_id) when is_binary(prefixed_id) do
    case Type.decode_object_id(prefixed_id) do
      {:ok, _prefix, uuid_bin} -> {:ok, uuid_bin}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Like `to_uuid/1` but returns the raw 16-byte UUID binary directly, raising on
  invalid input. This is the default inside Ash, where IDs are always valid.

  ## Examples

      iex> to_uuid!("user_CWzLBdFy2f1XhrtesFferY")
      <<93, 68, 109, 8, ...>>  # 16-byte binary
  """
  @spec to_uuid!(binary()) :: binary()
  def to_uuid!(prefixed_id) when is_binary(prefixed_id) do
    case to_uuid(prefixed_id) do
      {:ok, uuid_bin} -> uuid_bin
      {:error, _} -> raise ArgumentError, "invalid prefixed ID: #{inspect(prefixed_id)}"
    end
  end

  @doc """
  Decodes a prefixed ID into a UUID string, returning a tagged tuple.

  The non-bang variant, for validating **external** input at a boundary. Inside
  Ash, prefer `to_uuid_string!/1`.

  ## Examples

      iex> to_uuid_string("user_CWzLBdFy2f1XhrtesFferY")
      {:ok, "5d446d08-df6a-404d-a1e5-decc78429b3d"}

      iex> to_uuid_string("not a prefixed id")
      {:error, :invalid_prefixed_id}
  """
  @spec to_uuid_string(binary()) :: {:ok, String.t()} | {:error, :invalid_prefixed_id}
  def to_uuid_string(prefixed_id) when is_binary(prefixed_id) do
    with {:ok, uuid_bin} <- to_uuid(prefixed_id),
         {:ok, uuid_str} <- Ecto.UUID.load(uuid_bin) do
      {:ok, uuid_str}
    else
      :error -> {:error, :invalid_prefixed_id}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Like `to_uuid_string/1` but returns the UUID string directly, raising on
  invalid input. This is the default inside Ash.

  ## Examples

      iex> to_uuid_string!("user_CWzLBdFy2f1XhrtesFferY")
      "5d446d08-df6a-404d-a1e5-decc78429b3d"
  """
  @spec to_uuid_string!(binary()) :: String.t()
  def to_uuid_string!(prefixed_id) when is_binary(prefixed_id) do
    case to_uuid_string(prefixed_id) do
      {:ok, uuid_str} -> uuid_str
      {:error, _} -> raise ArgumentError, "invalid prefixed ID: #{inspect(prefixed_id)}"
    end
  end

  @doc """
  Searches the given domains for the resource that matches the given prefixed ID
  prefix.

  You can get the domains through `Application.get_env(:my_otp_app, :ash_domains, [])`

  ## Examples

      iex> find_resource_for_prefix(domains, "user")
      MyApp.Accounts.User

      iex> find_resource_for_prefix(domains, "florb")
      nil
  """
  def find_resource_for_prefix(domains, prefix) when is_binary(prefix) and is_list(domains) do
    Enum.find_value(domains, fn domain ->
      domain
      |> Ash.Domain.Info.resources()
      |> Enum.find_value(fn resource ->
        case AshPrefixedId.Info.prefixed_id_prefix(resource) do
          {:ok, ^prefix} -> resource
          _ -> nil
        end
      end)
    end)
  end

  @doc """
  Same as `find_resource_for_prefix/2` but accepts a (valid) prefixed ID.

  ## Examples

      iex> find_resource_for_id(domains, "user_CWzLBdFy2f1XhrtesFferY")
      MyApp.Accounts.User

      iex> find_resource_for_id(domains, "florb_CWzLBdFy2f1XhrtesFferY")
      nil
  """
  @spec find_resource_for_id([module()], String.t()) :: module() | nil
  def find_resource_for_id(domains, id) when is_list(domains) and is_binary(id) do
    case Type.decode_object_id(id) do
      {:ok, prefix, _uuid} -> find_resource_for_prefix(domains, prefix)
      _ -> nil
    end
  end

  @doc """
  Create a map of prefixes to the resources that use that prefix.
  """
  @spec map_prefixes_to_resources([module()]) :: %{String.t() => [module()]}
  def map_prefixes_to_resources(domains) do
    Enum.reduce(domains, %{}, fn domain, mapping ->
      domain
      |> Ash.Domain.Info.resources()
      |> Enum.reduce(mapping, fn resource, mapping ->
        case AshPrefixedId.Info.prefixed_id_prefix(resource) do
          {:ok, prefix} -> Map.update(mapping, prefix, [resource], &[resource | &1])
          _ -> mapping
        end
      end)
    end)
  end

  @doc """
  Same as `map_prefixes_to_resources`, but returns only the entries that
  contain more than resource for the given prefix.

  This function can be used to warn whenever duplicate prefixes are present in
  your modules.
  """
  @spec find_duplicate_prefixes([module()]) :: %{String.t() => [module()]}
  def find_duplicate_prefixes(domains) do
    domains
    |> map_prefixes_to_resources()
    |> Map.filter(fn
      {_key, [_]} -> false
      _ -> true
    end)
  end

  @doc """
  Encode a raw 16-byte UUID binary as a prefixed ID.

  The second argument is either a prefix string or a resource module. Passing
  the resource module resolves the prefix from its `prefixed_id` DSL, which
  avoids hard-coding (and drifting from) the configured prefix.

  Encoding is infallible, so there is no bang variant. This is an escape hatch
  for raw SQL / non-Ash code; inside Ash you receive prefixed IDs directly.

  ## Examples

      iex> to_prefixed_id(<<93, 68, 109, 8, ...>>, "user")
      "user_CWzLBdFy2f1XhrtesFferY"

      iex> to_prefixed_id(<<93, 68, 109, 8, ...>>, MyApp.Accounts.User)
      "user_CWzLBdFy2f1XhrtesFferY"
  """
  @spec to_prefixed_id(binary(), String.t() | module()) :: String.t()
  def to_prefixed_id(uuid_binary, prefix) when is_binary(prefix) do
    Type.encode_uuid(uuid_binary, prefix)
  end

  def to_prefixed_id(uuid_binary, resource) when is_atom(resource) do
    to_prefixed_id(uuid_binary, AshPrefixedId.Info.prefixed_id_prefix!(resource))
  end
end
