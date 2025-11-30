defmodule CodeMySpec.Specs.Spec do
  @moduledoc """
  Embedded schema representing a parsed spec file.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CodeMySpec.Specs.Function
  alias CodeMySpec.Specs.Field

  @type t :: %__MODULE__{
          module_name: String.t() | nil,
          type: String.t() | nil,
          description: String.t() | nil,
          delegates: [String.t()],
          dependencies: [String.t()],
          functions: [Function.t()],
          fields: [Field.t()]
        }

  @primary_key false
  embedded_schema do
    field :module_name, :string
    field :type, :string
    field :description, :string
    field :delegates, {:array, :string}, default: []
    field :dependencies, {:array, :string}, default: []

    embeds_many :functions, Function
    embeds_many :fields, Field
  end

  def changeset(spec, attrs) do
    spec
    |> cast(attrs, [:module_name, :type, :description, :delegates, :dependencies])
    |> validate_required([:module_name])
    |> validate_length(:module_name, min: 1, max: 255)
    |> validate_format(:module_name, ~r/^[A-Z][a-zA-Z0-9_.]*$/,
      message: "must be a valid Elixir module name"
    )
    |> cast_embed(:functions, with: &Function.changeset/2)
    |> cast_embed(:fields, with: &Field.changeset/2)
  end
end