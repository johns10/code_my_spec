defmodule CodeMySpec.ProjectCoordinator.ComponentAnalyzer do
  @moduledoc """
  Analyzes components against file system reality by mapping expected file paths,
  checking file existence, and looking up test status. Returns Component structs
  with ComponentStatus embedded and nested dependency trees.
  """

  alias CodeMySpec.Components.{Component, ComponentStatus, DependencyTree}
  alias CodeMySpec.Components
  alias CodeMySpec.Tests.TestResult
  alias CodeMySpec.Users.Scope
  require Logger

  @spec analyze_components([Component.t()], [String.t()], [TestResult.t()], keyword()) ::
          [Component.t()]
  def analyze_components(components, file_list, failures, opts \\ []) do
    scope = Keyword.get(opts, :scope, %Scope{})

    components
    |> Enum.map(&analyze_local_component_status(&1, file_list, failures, scope, opts))
    |> Enum.map(&check_local_requirements(&1, scope, opts))
    |> DependencyTree.build()
    |> Enum.map(&check_dependency_requirements(&1, scope, opts))
  end

  defp analyze_local_component_status(component, file_list, failing_tests, scope, opts) do
    # Compute ComponentStatus from file system analysis
    expected_files = map_expected_files(component)
    actual_files = check_file_existence(expected_files, file_list)
    relevant_failing_tests = filter_failing_tests(expected_files, failing_tests)

    component_status =
      ComponentStatus.from_analysis(expected_files, actual_files, relevant_failing_tests)

    update_attrs = %{component_status: component_status}
    opts = Keyword.put(opts, :broadcast, false)

    case Components.update_component(scope, component, update_attrs, opts) do
      {:ok, updated_component} ->
        # Ensure component_status is present (defensive programming)
        if updated_component.component_status do
          updated_component
        else
          Map.put(updated_component, :component_status, component_status)
        end

      {:error, changeset} ->
        Logger.error("#{__MODULE__} failed to update component", changeset: changeset)
        # Fallback: manually set component_status if update failed
        Map.put(component, :component_status, component_status)
    end
  end

  defp check_local_requirements(component, scope, opts) do
    Components.clear_requirements(scope, component, opts)

    requirements =
      Components.check_requirements(
        component,
        exclude: [:dependencies_satisfied]
      )
      |> Enum.map(fn requirement_attrs ->
        case Components.create_requirement(
               scope,
               component,
               requirement_attrs,
               opts
             ) do
          {:ok, requirement} ->
            Map.put(requirement, :component, %Ecto.Association.NotLoaded{})

          {:error, changeset} ->
            Logger.error("#{__MODULE__} failed check_local_requirements",
              changeset: changeset
            )

            nil
        end
      end)
      |> Enum.filter(&(&1 != nil))

    %{component | requirements: requirements}
  end

  defp check_dependency_requirements(component, scope, opts) do
    dependency_requirements =
      Components.check_requirements(
        component,
        include: [:dependencies_satisfied]
      )
      |> Enum.map(fn requirement_attrs ->
        case Components.create_requirement(
               scope,
               component,
               requirement_attrs,
               opts
             ) do
          {:ok, requirement} ->
            Map.put(requirement, :component, %Ecto.Association.NotLoaded{})

          {:error, changeset} ->
            Logger.error("#{__MODULE__} failed check_dependency_requirements",
              changeset: changeset
            )

            nil
        end
      end)
      |> Enum.filter(&(&1 != nil))

    # Merge dependency requirements with existing requirements
    all_requirements = (component.requirements || []) ++ dependency_requirements
    %{component | requirements: all_requirements}
  end

  defp map_expected_files(component) do
    full_module_name = "#{component.project.module_name}.#{component.module_name}"
    module_path = module_to_path(full_module_name)

    %{
      design_file: "docs/design/#{module_path}.md",
      code_file: "lib/#{module_path}.ex",
      test_file: "test/#{module_path}_test.exs"
    }
  end

  defp module_to_path(module_name) do
    module_name
    |> String.replace_prefix("", "")
    |> Macro.underscore()
    |> String.replace(".", "/")
    |> String.downcase()
  end

  defp check_file_existence(expected_files, file_list) do
    expected_files
    |> Map.values()
    |> Enum.filter(&(&1 in file_list))
  end

  defp filter_failing_tests(expected_files, failing_tests) do
    expected_test_file = expected_files.test_file

    failing_tests
    |> Enum.filter(fn %TestResult{} = result ->
      result.error.file == expected_test_file
    end)
    |> Enum.map(& &1.full_title)
  end
end
