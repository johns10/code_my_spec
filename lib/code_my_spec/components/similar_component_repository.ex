defmodule CodeMySpec.Components.SimilarComponentRepository do
  @moduledoc """
  Repository for SimilarComponent data access.
  """

  import Ecto.Query, warn: false
  alias CodeMySpec.Repo
  alias CodeMySpec.Components.{SimilarComponent, Component}
  alias CodeMySpec.Users.Scope

  @doc """
  Returns the list of similar components for a given component.
  """
  @spec list_similar_components(Scope.t(), Component.t()) :: [Component.t()]
  def list_similar_components(%Scope{active_project_id: project_id}, %Component{id: component_id}) do
    from(sc in SimilarComponent,
      join: c in Component,
      on: sc.component_id == c.id,
      join: similar in Component,
      on: sc.similar_component_id == similar.id,
      where: sc.component_id == ^component_id and c.project_id == ^project_id,
      preload: [similar_component: similar]
    )
    |> Repo.all()
    |> Enum.map(& &1.similar_component)
  end

  @doc """
  Creates a similar component relationship.
  Validates that both components exist within the same project.
  """
  @spec add_similar_component(Scope.t(), Component.t(), Component.t()) ::
          {:ok, SimilarComponent.t()} | {:error, Ecto.Changeset.t() | :components_not_in_same_project}
  def add_similar_component(
        %Scope{active_project_id: project_id},
        %Component{id: component_id},
        %Component{id: similar_component_id}
      ) do
    # Validate both components belong to same project
    with :ok <- validate_same_project(component_id, similar_component_id, project_id) do
      %SimilarComponent{}
      |> SimilarComponent.changeset(%{
        component_id: component_id,
        similar_component_id: similar_component_id
      })
      |> Repo.insert()
    end
  end

  @doc """
  Removes a similar component relationship.
  """
  @spec remove_similar_component(Scope.t(), Component.t(), Component.t()) ::
          {:ok, SimilarComponent.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def remove_similar_component(
        %Scope{active_project_id: project_id},
        %Component{id: component_id},
        %Component{id: similar_component_id}
      ) do
    from(sc in SimilarComponent,
      join: c in Component,
      on: sc.component_id == c.id,
      where:
        sc.component_id == ^component_id and
          sc.similar_component_id == ^similar_component_id and
          c.project_id == ^project_id
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      similar_component -> Repo.delete(similar_component)
    end
  end

  @doc """
  Syncs similar components for a component to match the given list of IDs.
  Removes relationships not in the list and adds new ones.
  """
  @spec sync_similar_components(Scope.t(), Component.t(), [Ecto.UUID.t()]) ::
          {:ok, Component.t()} | {:error, any()}
  def sync_similar_components(%Scope{} = scope, %Component{} = component, similar_ids)
      when is_list(similar_ids) do
    # Get current similar component IDs
    current_similar_ids =
      list_similar_components(scope, component)
      |> Enum.map(& &1.id)
      |> MapSet.new()

    new_similar_ids = MapSet.new(similar_ids)

    # IDs to remove
    to_remove = MapSet.difference(current_similar_ids, new_similar_ids)

    # IDs to add
    to_add = MapSet.difference(new_similar_ids, current_similar_ids)

    # Remove old relationships
    Enum.each(to_remove, fn similar_id ->
      similar_component = Repo.get!(Component, similar_id)
      remove_similar_component(scope, component, similar_component)
    end)

    # Add new relationships
    results =
      Enum.map(to_add, fn similar_id ->
        similar_component = Repo.get!(Component, similar_id)
        add_similar_component(scope, component, similar_component)
      end)

    # Check if all additions succeeded
    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil -> {:ok, component}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Preloads similar components for multiple components efficiently.
  Returns components with similar_components association loaded.
  """
  @spec preload_similar_components(Scope.t(), [Component.t()]) :: [Component.t()]
  def preload_similar_components(%Scope{} = _scope, components) when is_list(components) do
    component_ids = Enum.map(components, & &1.id)

    similar_map =
      from(sc in SimilarComponent,
        join: similar in Component,
        on: sc.similar_component_id == similar.id,
        where: sc.component_id in ^component_ids,
        preload: [similar_component: similar]
      )
      |> Repo.all()
      |> Enum.group_by(& &1.component_id)

    Enum.map(components, fn component ->
      similar_components =
        similar_map
        |> Map.get(component.id, [])
        |> Enum.map(& &1.similar_component)

      %{component | similar_components: similar_components}
    end)
  end

  @doc """
  Gets components that reference the given component as similar.
  (Reverse lookup - who considers this component similar?)
  """
  @spec list_referenced_by(Scope.t(), Component.t()) :: [Component.t()]
  def list_referenced_by(%Scope{active_project_id: project_id}, %Component{id: component_id}) do
    from(sc in SimilarComponent,
      join: c in Component,
      on: sc.component_id == c.id,
      join: similar in Component,
      on: sc.similar_component_id == similar.id,
      where: sc.similar_component_id == ^component_id and similar.project_id == ^project_id,
      preload: [component: c]
    )
    |> Repo.all()
    |> Enum.map(& &1.component)
  end

  # Private Functions

  @spec validate_same_project(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          :ok | {:error, :components_not_in_same_project}
  defp validate_same_project(component_id, similar_component_id, project_id) do
    components =
      from(c in Component,
        where: c.id in ^[component_id, similar_component_id] and c.project_id == ^project_id,
        select: c.id
      )
      |> Repo.all()

    if length(components) == 2 do
      :ok
    else
      {:error, :components_not_in_same_project}
    end
  end
end
