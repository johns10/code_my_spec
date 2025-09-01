defmodule CodeMySpec.ProjectCoordinator do
  @moduledoc """
  Synchronizes project component requirements with file system reality.

  Takes components, file list, and test results, analyzes everything, and returns
  the full nested component tree with statuses and requirements. Can filter to
  get the next actionable components.
  """

  alias CodeMySpec.Components
  alias CodeMySpec.ProjectCoordinator.ComponentAnalyzer
  alias CodeMySpec.Users.Scope
  alias CodeMySpec.Tests.TestRun

  @type component_list :: [Components.Component.t()]
  @type file_list :: [String.t()]

  @spec sync_project_requirements(Scope.t(), file_list(), TestRun.t(), keyword()) ::
          component_list()
  def sync_project_requirements(
        %Scope{} = scope,
        file_list,
        %TestRun{failures: failures},
        opts \\ []
      )
      when is_list(file_list) and is_list(failures) and is_list(opts) do
    scope
    |> Components.list_components_with_dependencies()
    |> ComponentAnalyzer.analyze_components(
      file_list,
      failures,
      Keyword.put(opts, :scope, scope)
    )
  end

  @spec get_next_actions(Scope.t(), pos_integer()) :: component_list()
  def get_next_actions(%Scope{} = scope, limit) when is_integer(limit) and limit > 0 do
    scope
    |> Components.components_with_unsatisfied_requirements()
    |> Enum.take(limit)
  end

  @spec get_next_actions(component_list(), pos_integer()) :: component_list()
  def get_next_actions(components, limit)
      when is_list(components) and is_integer(limit) and limit > 0 do
    components
    |> Enum.filter(&has_unsatisfied_requirements?/1)
    |> Enum.take(limit)
  end

  defp has_unsatisfied_requirements?(%Components.Component{requirements: requirements})
       when is_list(requirements) do
    Enum.any?(requirements, fn req -> not req.satisfied end)
  end

  defp has_unsatisfied_requirements?(_), do: false
end
