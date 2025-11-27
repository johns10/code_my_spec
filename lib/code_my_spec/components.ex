defmodule CodeMySpec.Components do
  @moduledoc """
  Manages component definitions, metadata, type classification, and inter-component dependencies for architectural design.
  """

  alias CodeMySpec.Components.{
    Component,
    ComponentRepository,
    DependencyRepository,
    SimilarComponentRepository,
    Registry,
    RequirementsRepository
  }

  alias CodeMySpec.Users.Scope
  require Logger

  @doc """
  Subscribes to scoped notifications about any component changes.

  The broadcasted messages match the pattern:

    * {:created, %Component{}}
    * {:updated, %Component{}}
    * {:deleted, %Component{}}

  """
  def subscribe_components(%Scope{} = scope) do
    key = scope.active_account.id

    Phoenix.PubSub.subscribe(CodeMySpec.PubSub, "user:#{key}:components")
  end

  defp broadcast(%Scope{} = scope, message) do
    key = scope.active_account.id

    Phoenix.PubSub.broadcast(CodeMySpec.PubSub, "user:#{key}:components", message)
  end

  defdelegate list_components(scope), to: ComponentRepository
  defdelegate list_child_components(scope, parent_component_id), to: ComponentRepository
  defdelegate list_components_with_dependencies(scope), to: ComponentRepository
  defdelegate list_contexts(scope), to: ComponentRepository
  defdelegate list_contexts_with_dependencies(scope), to: ComponentRepository
  defdelegate list_orphaned_contexts(scope), to: ComponentRepository
  defdelegate get_component!(scope, id), to: ComponentRepository
  defdelegate get_component_by_module_name(scope, id), to: ComponentRepository
  defdelegate get_component(scope, id), to: ComponentRepository
  defdelegate show_architecture(scope), to: ComponentRepository
  defdelegate upsert_component(scope, attrs), to: ComponentRepository
  defdelegate search_components_by_module_name(scope, module_name_pattern), to: ComponentRepository

  defdelegate create_components_with_dependencies(scope, component_attrs_list, dependencies),
    to: ComponentRepository

  @doc """
  Creates a component.

  ## Examples

      iex> create_component(scope, %{field: value})
      {:ok, %Component{}}

      iex> create_component(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_component(%Scope{} = scope, attrs) do
    with {:ok, component = %Component{}} <- ComponentRepository.create_component(scope, attrs) do
      broadcast(scope, {:created, component})
      {:ok, component}
    end
  end

  @doc """
  Updates a component.

  ## Examples

      iex> update_component(scope, component, %{field: new_value})
      {:ok, %Component{}}

      iex> update_component(scope, component, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_component(%Scope{} = scope, %Component{} = component, attrs, opts \\ []) do
    true = component.project_id == scope.active_project.id

    with {:ok, component = %Component{}} <-
           ComponentRepository.update_component(scope, component, attrs, opts) do
      if Keyword.get(opts, :broadcast, true), do: broadcast(scope, {:updated, component})
      {:ok, component}
    end
  end

  @doc """
  Deletes a component.

  ## Examples

      iex> delete_component(scope, component)
      {:ok, %Component{}}

      iex> delete_component(scope, component)
      {:error, %Ecto.Changeset{}}

  """
  def delete_component(%Scope{} = scope, %Component{} = component) do
    true = component.project_id == scope.active_project.id

    with {:ok, component = %Component{}} <- ComponentRepository.delete_component(scope, component) do
      broadcast(scope, {:deleted, component})
      {:ok, component}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking component changes.

  ## Examples

      iex> change_component(scope, component)
      %Ecto.Changeset{data: %Component{}}

  """
  def change_component(%Scope{} = scope, %Component{} = component, attrs \\ %{}) do
    true = component.project_id == scope.active_project.id

    Component.changeset(component, attrs, scope)
  end

  def check_requirements(component, opts) do
    include_types = Keyword.get(opts, :include, [])
    exclude_types = Keyword.get(opts, :exclude, [])

    Registry.get_requirements_for_type(component.type)
    |> Enum.filter(fn %{name: name} ->
      exclude = length(exclude_types) > 0 and name in exclude_types

      include =
        (length(include_types) > 0 and name in include_types) or length(include_types) == 0

      include && !exclude
    end)
    |> Enum.map(fn requirement_spec ->
      checker = requirement_spec.checker
      checker.check(requirement_spec, component)
    end)
  end

  defdelegate clear_requirements(scope, component, opts \\ []), to: RequirementsRepository
  defdelegate create_requirement(scope, component, attrs, opts \\ []), to: RequirementsRepository
  defdelegate components_with_unsatisfied_requirements(scope), to: RequirementsRepository
  defdelegate list_dependencies(scope), to: DependencyRepository
  defdelegate get_dependency!(scope, id), to: DependencyRepository
  defdelegate create_dependency(scope, attrs), to: DependencyRepository
  defdelegate delete_dependency(scope, dependency), to: DependencyRepository
  defdelegate validate_dependency_graph(scope), to: DependencyRepository
  defdelegate resolve_dependency_order(scope), to: DependencyRepository

  # Similar Components
  defdelegate list_similar_components(scope, component), to: SimilarComponentRepository

  defdelegate add_similar_component(scope, component, similar_component),
    to: SimilarComponentRepository

  defdelegate remove_similar_component(scope, component, similar_component),
    to: SimilarComponentRepository

  defdelegate sync_similar_components(scope, component, similar_ids),
    to: SimilarComponentRepository

  defdelegate preload_similar_components(scope, components), to: SimilarComponentRepository
  defdelegate list_referenced_by(scope, component), to: SimilarComponentRepository
end
