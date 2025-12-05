defmodule CodeMySpec.Components.RequirementsRepository do
  import Ecto.Query, warn: false

  alias CodeMySpec.Repo
  alias CodeMySpec.Users.Scope
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Components.Requirements.Requirement

  @type requirement_attrs :: %{
          name: String.t(),
          type: atom(),
          description: String.t(),
          checker_module: String.t(),
          satisfied_by: String.t() | nil,
          satisfied: boolean(),
          checked_at: DateTime.t() | nil,
          details: map()
        }

  @spec create_requirement(Scope.t(), Component.t(), requirement_attrs(), keyword()) ::
          {:ok, Requirement.t()} | {:error, Ecto.Changeset.t()}
  def create_requirement(%Scope{}, %Component{} = component, attrs, opts \\ []) do
    changeset =
      %Requirement{}
      |> Requirement.changeset(attrs)
      |> Ecto.Changeset.put_assoc(:component, component)

    if Keyword.get(opts, :persist, true) do
      Repo.insert(changeset)
    else
      Ecto.Changeset.apply_action(changeset, :insert)
    end
  end

  @spec update_requirement(Scope.t(), Requirement.t(), requirement_attrs()) ::
          {:ok, Requirement.t()} | {:error, Ecto.Changeset.t()}
  def update_requirement(%Scope{}, %Requirement{} = requirement, attrs) do
    requirement
    |> Requirement.update_changeset(attrs)
    |> Repo.update()
  end

  @spec clear_requirements(Scope.t(), Component.t(), list()) :: Component.t()
  def clear_requirements(%Scope{}, %Component{} = component, opts) do
    if Keyword.get(opts, :persist, false) do
      Requirement
      |> where([r], r.component_id == ^component.id)
      |> Repo.delete_all()
    end
  end

  @spec components_with_unsatisfied_requirements(Scope.t()) :: [Component.t()]
  def components_with_unsatisfied_requirements(%Scope{active_project_id: project_id}) do
    Component
    |> where([c], c.project_id == ^project_id)
    |> join(:inner, [c], r in assoc(c, :requirements))
    |> where([c, r], r.satisfied == false)
    |> distinct([c], c.id)
    |> preload(:requirements)
    |> Repo.all()
  end

  @spec components_ready_for_work(Scope.t()) :: [Component.t()]
  def components_ready_for_work(%Scope{active_project_id: project_id}) do
    # Get components that either have no requirements or all requirements are satisfied
    components_with_requirements =
      Component
      |> where([c], c.project_id == ^project_id)
      |> join(:inner, [c], r in assoc(c, :requirements))
      |> where([c, r], r.satisfied == false)
      |> select([c], c.id)
      |> Repo.all()

    Component
    |> where([c], c.project_id == ^project_id)
    |> where([c], c.id not in ^components_with_requirements)
    |> preload(:requirements)
    |> Repo.all()
  end
end
