defmodule CodeMySpec.RequirementsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CodeMySpec.Components.RequirementsRepository` context.
  """

  alias CodeMySpec.Components.RequirementsRepository

  @doc """
  Generate a requirement.
  """
  def requirement_fixture(scope, component, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "design_file",
        type: :file_existence,
        description: "Component design documentation exists",
        checker_module: "CodeMySpec.Components.Requirements.FileExistenceChecker",
        satisfied_by: nil,
        satisfied: false,
        checked_at: DateTime.utc_now(),
        details: %{}
      })

    {:ok, requirement} = RequirementsRepository.create_requirement(scope, component, attrs)
    requirement
  end

  @doc """
  Generate requirement attrs for testing.
  """
  def requirement_attrs(attrs \\ %{}) do
    Map.merge(
      %{
        name: "design_file",
        type: :file_existence,
        description: "Component design documentation exists",
        checker_module: "CodeMySpec.Components.Requirements.FileExistenceChecker",
        satisfied_by: nil,
        satisfied: false,
        checked_at: DateTime.utc_now(),
        details: %{}
      },
      attrs
    )
  end

  @doc """
  Generate multiple requirements for a component.
  """
  def requirements_fixture(scope, component, count \\ 3) do
    Enum.map(1..count, fn i ->
      requirement_fixture(scope, component, %{
        name: "requirement_#{i}",
        description: "Test requirement #{i}"
      })
    end)
  end
end
