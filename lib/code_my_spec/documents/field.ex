defmodule CodeMySpec.Documents.Field do
  @moduledoc """
  Embedded schema representing a schema field.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          field: String.t() | nil,
          type: String.t() | nil,
          required: String.t() | nil,
          description: String.t() | nil,
          constraints: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :field, :string
    field :type, :string
    field :required, :string
    field :description, :string
    field :constraints, :string
  end

  def changeset(field, attrs) do
    field
    |> cast(attrs, [:field, :type, :required, :description, :constraints])
    |> validate_required([:field, :type, :required])
    |> validate_length(:field, min: 1, max: 255)
  end
end
