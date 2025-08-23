defmodule CodeMySpec.Components.Component do
  @moduledoc """
  Ecto schema for Component entities representing Elixir code files within project architecture.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CodeMySpec.Components.Dependency
  alias CodeMySpec.Projects.Project
  alias CodeMySpec.Components.Requirements.Requirement
  alias CodeMySpec.Components.ComponentStatus

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          type: atom(),
          module_name: String.t(),
          description: String.t() | nil,
          priority: integer() | nil,
          project_id: integer(),
          project: Project.t() | Ecto.Association.NotLoaded.t(),
          outgoing_dependencies: [Dependency.t()] | Ecto.Association.NotLoaded.t(),
          incoming_dependencies: [Dependency.t()] | Ecto.Association.NotLoaded.t(),
          dependencies: [t()] | Ecto.Association.NotLoaded.t(),
          dependents: [t()] | Ecto.Association.NotLoaded.t(),
          stories: [CodeMySpec.Stories.Story.t()] | Ecto.Association.NotLoaded.t(),
          requirements: [Requirement.t()] | Ecto.Association.NotLoaded.t(),
          component_status: ComponentStatus.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "components" do
    field :name, :string

    field :type, Ecto.Enum,
      values: [
        :genserver,
        :context,
        :coordination_context,
        :schema,
        :repository,
        :task,
        :registry,
        :other
      ]

    field :module_name, :string
    field :description, :string
    field :priority, :integer

    belongs_to :project, Project

    has_many :outgoing_dependencies, Dependency, foreign_key: :source_component_id
    has_many :incoming_dependencies, Dependency, foreign_key: :target_component_id

    has_many :dependencies, through: [:outgoing_dependencies, :target_component]
    has_many :dependents, through: [:incoming_dependencies, :source_component]
    has_many :stories, CodeMySpec.Stories.Story
    has_many :requirements, Requirement

    embeds_one :component_status, ComponentStatus

    timestamps(type: :utc_datetime)
  end

  def changeset(component, attrs, %CodeMySpec.Users.Scope{} = scope) do
    component
    |> cast(attrs, [:name, :type, :module_name, :description, :priority])
    |> validate_required([:name, :type, :module_name])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:module_name, min: 1, max: 255)
    |> validate_format(:module_name, ~r/^[A-Z][a-zA-Z0-9_.]*$/,
      message: "must be a valid Elixir module name"
    )
    |> put_scope_associations(scope)
    |> unique_constraint([:name, :project_id])
    |> unique_constraint([:module_name, :project_id])
  end

  @spec put_scope_associations(Ecto.Changeset.t(), CodeMySpec.Users.Scope.t()) ::
          Ecto.Changeset.t()
  defp put_scope_associations(changeset, %{active_project: %{id: project_id}}) do
    changeset
    |> put_change(:project_id, project_id)
  end
end
