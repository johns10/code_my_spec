defmodule CodeMySpec.Components do
  @moduledoc """
  Manages component definitions, metadata, type classification, and inter-component dependencies for architectural design.
  """

  alias CodeMySpec.Components.{ComponentRepository, DependencyRepository}

  defdelegate list_components(scope), to: ComponentRepository
  defdelegate get_component!(scope, id), to: ComponentRepository
  defdelegate create_component(scope, attrs), to: ComponentRepository
  defdelegate update_component(scope, component, attrs), to: ComponentRepository
  defdelegate delete_component(scope, component), to: ComponentRepository
  defdelegate list_dependencies(scope), to: DependencyRepository
  defdelegate get_dependency!(scope, id), to: DependencyRepository
  defdelegate create_dependency(attrs), to: DependencyRepository
  defdelegate delete_dependency(scope, dependency), to: DependencyRepository
  defdelegate validate_dependency_graph(scope), to: DependencyRepository
  defdelegate resolve_dependency_order(scope), to: DependencyRepository
end
