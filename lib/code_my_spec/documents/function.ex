defmodule CodeMySpec.Documents.Function do
  @moduledoc """
  Embedded schema representing a function from a spec document.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          name: String.t() | nil,
          description: String.t() | nil,
          spec: String.t() | nil,
          process: String.t() | nil,
          test_assertions: [String.t()]
        }

  @primary_key false
  embedded_schema do
    field :name, :string
    field :description, :string
    field :spec, :string
    field :process, :string
    field :test_assertions, {:array, :string}, default: []
  end

  def changeset(function, attrs) do
    function
    |> cast(attrs, [:name, :description, :spec, :process, :test_assertions])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
  end
end
