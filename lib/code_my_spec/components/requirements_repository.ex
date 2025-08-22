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

  @spec create_requirement(Scope.t(), Component.t(), requirement_attrs()) ::
          {:ok, Requirement.t()} | {:error, Ecto.Changeset.t()}
  def create_requirement(%Scope{}, %Component{} = component, attrs) do
    %Requirement{}
    |> Requirement.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:component, component)
    |> Repo.insert()
  end

  @spec get_requirement(Scope.t(), integer()) :: Requirement.t() | nil
  def get_requirement(%Scope{active_project_id: project_id}, requirement_id) do
    Requirement
    |> join(:inner, [r], c in assoc(r, :component))
    |> where([r, c], r.id == ^requirement_id and c.project_id == ^project_id)
    |> Repo.one()
  end

  @spec update_requirement(Scope.t(), Requirement.t(), requirement_attrs()) ::
          {:ok, Requirement.t()} | {:error, Ecto.Changeset.t()}
  def update_requirement(%Scope{}, %Requirement{} = requirement, attrs) do
    requirement
    |> Requirement.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_requirement(Scope.t(), Requirement.t()) ::
          {:ok, Requirement.t()} | {:error, Ecto.Changeset.t()}
  def delete_requirement(%Scope{}, %Requirement{} = requirement) do
    Repo.delete(requirement)
  end

  @spec list_requirements_for_component(Scope.t(), integer()) :: [Requirement.t()]
  def list_requirements_for_component(%Scope{active_project_id: project_id}, component_id) do
    Requirement
    |> join(:inner, [r], c in assoc(r, :component))
    |> where([r, c], r.component_id == ^component_id and c.project_id == ^project_id)
    |> Repo.all()
  end

  @spec by_satisfied_status(Ecto.Query.t(), boolean()) :: Ecto.Query.t()
  def by_satisfied_status(query, satisfied) do
    where(query, [r], r.satisfied == ^satisfied)
  end

  @spec by_requirement_name(Ecto.Query.t(), atom()) :: Ecto.Query.t()
  def by_requirement_name(query, requirement_name) do
    name_string = Atom.to_string(requirement_name)
    where(query, [r], r.name == ^name_string)
  end

  @spec recreate_component_requirements(Scope.t(), Component.t(), [Requirement.t()]) ::
          {:ok, [Requirement.t()]}
  def recreate_component_requirements(%Scope{} = scope, %Component{} = component, requirements) do
    Repo.transaction(fn ->
      # Delete existing requirements for the component
      Requirement
      |> where([r], r.component_id == ^component.id)
      |> Repo.delete_all()

      # Insert new requirements
      Enum.map(requirements, fn req_attrs ->
        case create_requirement(scope, component, req_attrs) do
          {:ok, requirement} -> requirement
          {:error, _changeset} -> nil
        end
      end)
      |> Enum.filter(&(&1 != nil))
    end)
    |> case do
      {:ok, requirements} -> {:ok, requirements}
      {:error, _} -> {:ok, []}
    end
  end

  @spec clear_project_requirements(Scope.t()) :: :ok
  def clear_project_requirements(%Scope{active_project_id: project_id}) do
    Requirement
    |> join(:inner, [r], c in assoc(r, :component))
    |> where([r, c], c.project_id == ^project_id)
    |> Repo.delete_all()

    :ok
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