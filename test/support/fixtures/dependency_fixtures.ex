defmodule CodeMySpec.DependencyFixtures do
  @moduledoc """
  This module defines test helpers for creating
  dependency entities via the `CodeMySpec.Components.DependencyRepository`.
  """

  alias CodeMySpec.Components.DependencyRepository

  @doc """
  Generate a dependency between two components.
  """
  def dependency_fixture(scope, source_component, target_component, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        source_component_id: source_component.id,
        target_component_id: target_component.id,
        type: :call
      })

    {:ok, dependency} = DependencyRepository.create_dependency(scope, attrs)
    dependency
  end

  @doc """
  Generate multiple dependencies creating a chain.
  Returns list of dependencies in order: first -> second -> third
  """
  def dependency_chain_fixture(scope, components, type \\ :call) when length(components) >= 2 do
    components
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [source, target] ->
      dependency_fixture(scope, source, target, %{type: type})
    end)
  end

  @doc """
  Generate circular dependencies between components.
  Creates A -> B -> A cycle.
  """
  def circular_dependency_fixture(scope, comp_a, comp_b, type \\ :call) do
    dep1 = dependency_fixture(scope, comp_a, comp_b, %{type: type})
    dep2 = dependency_fixture(scope, comp_b, comp_a, %{type: type})
    {dep1, dep2}
  end
end