defmodule CodeMySpec.Components.Dependency do
  @moduledoc """
  Ecto schema for Dependency entities representing relationships between
  Elixir components within project architecture.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CodeMySpec.Components.Component

  @type t :: %__MODULE__{
          id: integer() | nil,
          type: dependency_type(),
          source_component_id: integer(),
          target_component_id: integer(),
          source_component: Component.t() | Ecto.Association.NotLoaded.t(),
          target_component: Component.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @type dependency_type :: :require | :import | :alias | :use | :call | :other

  schema "dependencies" do
    field :type, Ecto.Enum, values: [:require, :import, :alias, :use, :call, :other]

    belongs_to :source_component, Component
    belongs_to :target_component, Component

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a dependency with validation rules.
  """
  def changeset(dependency, attrs) do
    dependency
    |> cast(attrs, [:type, :source_component_id, :target_component_id])
    |> validate_required([:type, :source_component_id, :target_component_id])
    |> validate_no_self_dependency()
    |> unique_constraint([:source_component_id, :target_component_id, :type])
    |> foreign_key_constraint(:source_component_id)
    |> foreign_key_constraint(:target_component_id)
  end

  @spec validate_no_self_dependency(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_no_self_dependency(changeset) do
    source_id = get_field(changeset, :source_component_id)
    target_id = get_field(changeset, :target_component_id)

    case {source_id, target_id} do
      {id, id} when not is_nil(id) ->
        add_error(changeset, :target_component_id, "cannot depend on itself")

      _ ->
        changeset
    end
  end
end
