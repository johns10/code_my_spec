defmodule CodeMySpec.Requirements.RequirementsRepository do
  import Ecto.Query, warn: false

  alias CodeMySpec.Repo
  alias CodeMySpec.Users.Scope
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Requirements.Requirement

  @spec create_requirement(Scope.t(), Component.t(), Requirement.requirement_attrs(), keyword()) ::
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

  @spec update_requirement(Scope.t(), Requirement.t(), Requirement.requirement_attrs()) ::
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

    component
    |> Map.put(:outgoing_dependencies, [])
    |> Map.put(:incoming_dependencies, [])
  end
end
