defmodule AshPrefixedId.Info do
  use Spark.InfoGenerator, extension: AshPrefixedId, sections: [:prefixed_id]
end
