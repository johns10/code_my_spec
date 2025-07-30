defmodule CodeMySpec.ComponentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CodeMySpec.Components` context.
  """

  alias CodeMySpec.Components.{ComponentRepository, Dependency}
  alias CodeMySpec.Repo

  @doc """
  Generate a component.
  """
  def component_fixture(scope, attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    attrs =
      Enum.into(attrs, %{
        name: "TestComponent#{unique_id}",
        type: :context,
        module_name: "MyApp.TestComponent#{unique_id}",
        description: "A test component"
      })

    {:ok, component} = ComponentRepository.create_component(scope, attrs)
    component
  end

  @doc """
  Generate multiple components for testing relationships.
  """
  def component_with_dependencies_fixture(scope, attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    parent_attrs =
      Map.merge(
        %{
          name: "ParentComponent#{unique_id}",
          type: :context,
          module_name: "MyApp.ParentComponent#{unique_id}"
        },
        attrs
      )

    child_attrs = %{
      name: "ChildComponent#{unique_id}",
      type: :schema,
      module_name: "MyApp.ChildComponent#{unique_id}"
    }

    {:ok, parent} = ComponentRepository.create_component(scope, parent_attrs)
    {:ok, child} = ComponentRepository.create_component(scope, child_attrs)

    # Create dependency relationship directly via changeset
    %Dependency{}
    |> Dependency.changeset(%{
      source_component_id: parent.id,
      target_component_id: child.id,
      type: :call
    })
    |> Repo.insert!()

    {parent, child}
  end

  @doc """
  Generate a genserver component.
  """
  def genserver_component_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "TestGenServer",
        type: :genserver,
        module_name: "MyApp.TestGenServer",
        description: "A test GenServer"
      })

    component_fixture(scope, attrs)
  end

  @doc """
  Generate a schema component.
  """
  def schema_component_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "TestSchema",
        type: :schema,
        module_name: "MyApp.TestSchema",
        description: "A test schema"
      })

    component_fixture(scope, attrs)
  end

  @doc """
  Generate a repository component.
  """
  def repository_component_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "TestRepository",
        type: :repository,
        module_name: "MyApp.TestRepository",
        description: "A test repository"
      })

    component_fixture(scope, attrs)
  end
end
