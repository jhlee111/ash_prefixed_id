defmodule AshPrefixedId.Test.Resources.Post do
  @moduledoc false

  use Ash.Resource,
    domain: AshPrefixedId.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPrefixedId]

  prefixed_id do
    prefix "post"
  end

  ets do
    private?(true)
  end

  actions do
    defaults([:read, :destroy, create: [:title], update: [:title]])
  end

  attributes do
    uuid_v7_primary_key(:id)
    attribute(:title, :string, public?: true)
  end

  relationships do
    has_many(:comments, AshPrefixedId.Test.Resources.Comment)
  end
end
