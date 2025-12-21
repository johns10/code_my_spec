defmodule CodeMySpec.Documents.SpecComponent do
  @moduledoc """
  Embedded schema representing a component reference from a context design document.
  Contains module name, name, and description for components listed in the Components section.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          module_name: String.t(),
          description: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :module_name, :string
    field :description, :string
  end

  def changeset(spec_component \\ %__MODULE__{}, attrs) do
    spec_component
    |> cast(attrs, [:module_name, :description])
    |> validate_required([:module_name])
  end
end
