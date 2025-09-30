defmodule CodeMySpec.Documents.ComponentDesign do
  @moduledoc """
  Embedded schema representing a Component Design specification.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias CodeMySpec.Documents.FieldDescriptionRegistry

  @behaviour CodeMySpec.Documents.DocumentBehaviour

  @primary_key false
  embedded_schema do
    field :purpose, :string
    field :public_api, :string
    field :execution_flow, :string
    field :other_sections, :map
  end

  def changeset(component_design, attrs, _scope \\ nil) do
    component_design
    |> cast(attrs, [:purpose, :public_api, :execution_flow, :other_sections])
    |> validate_required(required_fields())
  end

  def required_fields(), do: [:purpose, :public_api, :execution_flow]

  def overview,
    do: """
    Components are Elixir modules that encapsulate focused business logic within a Phoenix context.
    Each component handles a specific responsibility.
    The context module orchestrates these components to provide cohesive domain functionality.
    """

  def field_descriptions do
    %{
      purpose: FieldDescriptionRegistry.component_purpose(),
      public_api: FieldDescriptionRegistry.public_api(),
      execution_flow: FieldDescriptionRegistry.execution_flow(),
      other_sections: "Additional sections for extended documentation"
    }
  end
end
