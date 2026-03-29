defmodule AshPrefixedId.Test.Resources.Unrelated do
  @moduledoc false

  use Ash.Resource,
    domain: AshPrefixedId.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPrefixedId]

  prefixed_id do
    # Duplicate with comment
    prefix "c"
  end

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
  end
end
