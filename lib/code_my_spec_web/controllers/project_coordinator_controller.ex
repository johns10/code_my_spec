defmodule CodeMySpecWeb.ProjectCoordinatorController do
  use CodeMySpecWeb, :controller

  alias CodeMySpec.ProjectCoordinator
  require Logger

  action_fallback CodeMySpecWeb.FallbackController

  def sync_requirements(conn, params) do
    scope = conn.assigns.current_scope
    persist = params["persist"] || false

    with file_list <- Map.get(params, "file_list", []),
         test_results_data <- Map.get(params, "test_results", %{}),
         changeset <- CodeMySpec.Tests.TestRun.changeset(test_results_data),
         test_run <- Ecto.Changeset.apply_changes(changeset) do
      opts = [persist: persist]

      components =
        ProjectCoordinator.sync_project_requirements(scope, file_list, test_run, opts)

      render(conn, :sync_requirements, components: components, next_components: [])
    end
  end

  def next_actions(conn, params) do
    scope = conn.assigns.current_scope
    limit = parse_limit(params["limit"])
    actions = ProjectCoordinator.get_next_actions(scope, limit)

    render(conn, :next_actions, actions: actions)
  end

  defp parse_limit(nil), do: 5
  defp parse_limit(limit) when is_integer(limit), do: limit

  defp parse_limit(limit) when is_binary(limit) do
    case Integer.parse(limit) do
      {int, _} -> int
      :error -> 5
    end
  end

  defp parse_limit(_), do: 5
end
