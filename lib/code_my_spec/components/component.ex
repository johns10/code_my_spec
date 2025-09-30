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
  alias CodeMySpec.Accounts.Account

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          type: atom(),
          module_name: String.t(),
          description: String.t() | nil,
          priority: integer() | nil,
          account_id: integer(),
          project_id: integer(),
          parent_component_id: integer() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          project: Project.t() | Ecto.Association.NotLoaded.t(),
          parent_component: t() | Ecto.Association.NotLoaded.t() | nil,
          child_components: [t()] | Ecto.Association.NotLoaded.t(),
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

  @type component_type ::
          :genserver
          | :context
          | :coordination_context
          | :schema
          | :repository
          | :task
          | :registry
          | :other

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

    belongs_to :account, Account
    belongs_to :project, Project
    belongs_to :parent_component, __MODULE__

    has_many :child_components, __MODULE__, foreign_key: :parent_component_id
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
    |> cast(attrs, [:name, :type, :module_name, :description, :priority, :parent_component_id])
    |> validate_required([:name, :type, :module_name])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:module_name, min: 1, max: 255)
    |> validate_format(:module_name, ~r/^[A-Z][a-zA-Z0-9_.]*$/,
      message: "must be a valid Elixir module name"
    )
    |> validate_no_self_parent()
    |> put_scope_associations(scope)
    |> unique_constraint([:module_name, :project_id])
    |> foreign_key_constraint(:parent_component_id)
  end

  @spec validate_no_self_parent(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_no_self_parent(changeset) do
    component_id = get_field(changeset, :id)
    parent_id = get_field(changeset, :parent_component_id)

    case {component_id, parent_id} do
      {id, id} when not is_nil(id) ->
        add_error(changeset, :parent_component_id, "cannot be its own parent")

      _ ->
        changeset
    end
  end

  @spec put_scope_associations(Ecto.Changeset.t(), CodeMySpec.Users.Scope.t()) ::
          Ecto.Changeset.t()
  defp put_scope_associations(changeset, %{
         active_account: %{id: account_id},
         active_project: %{id: project_id}
       }) do
    changeset
    |> put_change(:account_id, account_id)
    |> put_change(:project_id, project_id)
  end
end
