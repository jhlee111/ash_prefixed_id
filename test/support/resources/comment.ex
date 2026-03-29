defmodule AshPrefixedId.Test.Resources.Comment do
  @moduledoc false

  alias AshPrefixedId.Test.Resources.Post

  use Ash.Resource,
    domain: AshPrefixedId.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPrefixedId]

  prefixed_id do
    prefix "c"
  end

  ets do
    private?(true)
  end

  actions do
    defaults([:read, :destroy, create: [:body, :post_id], update: [:body]])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:body, :string, public?: true)
  end

  relationships do
    belongs_to(:post, Post)
  end
end
