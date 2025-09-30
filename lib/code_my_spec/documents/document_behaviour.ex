defmodule CodeMySpec.Documents.DocumentBehaviour do
  @moduledoc """
  Behaviour for document schemas that define structured specifications.
  """

  @callback overview() :: String.t()
  @callback field_descriptions() :: %{atom() => String.t()}
  @callback required_fields() :: [atom()]
  @callback changeset(struct(), map(), any()) :: Ecto.Changeset.t()
end