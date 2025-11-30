defmodule CodeMySpec.Components.SimilarComponent do
  @moduledoc """
  Ecto schema for SimilarComponent entities representing similarity relationships between components.
  Similar components serve as design inspiration and context when creating or modifying components.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CodeMySpec.Components.Component

  @type t :: %__MODULE__{
          id: integer(),
          component_id: Ecto.UUID.t(),
          similar_component_id: Ecto.UUID.t(),
          component: Component.t() | Ecto.Association.NotLoaded.t(),
          similar_component: Component.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "similar_components" do
    belongs_to :component, Component, type: :binary_id
    belongs_to :similar_component, Component, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(similar_component, attrs) do
    similar_component
    |> cast(attrs, [:component_id, :similar_component_id])
    |> validate_required([:component_id, :similar_component_id])
    |> validate_no_self_similarity()
    |> unique_constraint([:component_id, :similar_component_id])
    |> foreign_key_constraint(:component_id)
    |> foreign_key_constraint(:similar_component_id)
  end

  defp validate_no_self_similarity(changeset) do
    component_id = get_field(changeset, :component_id)
    similar_id = get_field(changeset, :similar_component_id)

    if component_id && similar_id && component_id == similar_id do
      add_error(changeset, :similar_component_id, "cannot be similar to itself")
    else
      changeset
    end
  end
end
