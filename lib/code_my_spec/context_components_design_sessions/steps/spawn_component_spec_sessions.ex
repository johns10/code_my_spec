defmodule CodeMySpec.ContextComponentsDesignSessions.Steps.SpawnComponentSpecSessions do
  @moduledoc """
  Creates child ComponentDesignSession records for each component within the target context.

  Returns a spawn_sessions command containing child_session_ids in metadata, enabling the
  client to orchestrate parallel autonomous design generation across all context components.
  """

  @behaviour CodeMySpec.Sessions.StepBehaviour

  require Logger

  alias CodeMySpec.Components
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Sessions
  alias CodeMySpec.Sessions.{Command, Session}
  alias CodeMySpec.Sessions.SessionsRepository
  alias CodeMySpec.Users.Scope
  alias CodeMySpec.Utils

  @impl true
  def get_command(%Scope{} = scope, %Session{} = session, _opts) do
    with {:ok, context_component} <- get_context_component(scope, session),
         {:ok, parent_session} <- get_parent_session(scope, session),
         {:ok, child_sessions} <-
           get_or_create_child_sessions(scope, parent_session, context_component) do
      child_session_ids = Enum.map(child_sessions, & &1.id)

      command =
        Command.new(__MODULE__, "spawn_sessions",
          metadata: %{child_session_ids: child_session_ids}
        )

      {:ok, command}
    end
  end

  @impl true
  def handle_result(%Scope{} = scope, %Session{} = session, result, _opts) do
    with {:ok, parent_session} <- get_parent_session(scope, session),
         :ok <- validate_child_sessions_status(parent_session.child_sessions) do
      {:ok, %{}, %{result | status: :ok}}
    else
      {:error, "Session not found"} = error ->
        error

      {:error, error_message} ->
        {:ok, %{}, %{result | status: :error, error_message: error_message}}
    end
  end

  # Private Functions

  defp get_parent_session(%Scope{} = scope, %Session{id: id}) do
    case SessionsRepository.get_session(scope, id) do
      nil -> {:error, "Session not found"}
      session -> {:ok, session}
    end
  end

  defp get_context_component(_scope, %Session{component: nil}) do
    {:error, "Context component not found"}
  end

  defp get_context_component(_scope, %Session{component: component}) do
    {:ok, component}
  end

  defp get_or_create_child_sessions(
         %Scope{} = scope,
         %Session{child_sessions: child_sessions} = parent_session,
         %Component{} = context_component
       ) do
    case child_sessions do
      [] ->
        # No child sessions exist, create them
        create_new_child_sessions(scope, parent_session, context_component)

      existing_sessions ->
        # Child sessions exist, validate they're the correct type
        case validate_child_sessions_type(existing_sessions) do
          :ok -> {:ok, existing_sessions}
          {:error, _} = error -> error
        end
    end
  end

  defp validate_child_sessions_type(child_sessions) do
    invalid_sessions =
      Enum.reject(child_sessions, fn session ->
        session.type == CodeMySpec.ComponentSpecSessions
      end)

    case invalid_sessions do
      [] ->
        :ok

      [session | _] ->
        {:error,
         "Invalid child session type: expected ComponentSpecSessions, got #{inspect(session.type)}"}
    end
  end

  defp create_new_child_sessions(
         %Scope{} = scope,
         %Session{} = parent_session,
         %Component{} = context_component
       ) do
    with {:ok, child_components} <- get_child_components(scope, context_component),
         {:ok, context_design_path} <- get_context_design_path(context_component, parent_session) do
      create_child_sessions(
        scope,
        parent_session,
        context_component,
        child_components,
        context_design_path
      )
    end
  end

  defp get_child_components(%Scope{} = scope, %Component{id: parent_id}) do
    case Components.list_child_components(scope, parent_id) do
      [] -> {:error, "No child components found for context"}
      components -> {:ok, components}
    end
  end

  defp get_context_design_path(%Component{} = context_component, %Session{project: project}) do
    %{design_file: design_path} = Utils.component_files(context_component, project)
    {:ok, design_path}
  end

  defp create_child_sessions(
         %Scope{} = scope,
         %Session{} = parent_session,
         %Component{} = context_component,
         child_components,
         context_design_path
       ) do
    results =
      Enum.map(child_components, fn component ->
        create_child_session(
          scope,
          parent_session,
          context_component,
          component,
          context_design_path
        )
      end)

    {successful, failed} = partition_results(results)

    with {:has_successful, true} <- {:has_successful, not Enum.empty?(successful)} do
      log_failures(failed)
      {:ok, successful}
    else
      {:has_successful, false} -> {:error, "Failed to spawn any child sessions"}
    end
  end

  defp create_child_session(
         %Scope{} = scope,
         %Session{} = parent_session,
         %Component{} = context_component,
         %Component{} = component,
         context_design_path
       ) do
    attrs = %{
      type: CodeMySpec.ComponentSpecSessions,
      component_id: component.id,
      session_id: parent_session.id,
      execution_mode: :agentic,
      agent: parent_session.agent,
      environment: parent_session.environment,
      project_id: scope.active_project_id,
      state: %{
        parent_context_name: context_component.name,
        context_design_path: context_design_path
      }
    }

    case Sessions.create_session(scope, attrs) do
      {:ok, session} ->
        {:ok, session}

      {:error, changeset} ->
        Logger.error(
          "Failed to create child session for component #{component.name}: #{inspect(changeset)}"
        )

        {:error, component}
    end
  end

  defp partition_results(results) do
    successful =
      results
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, session} -> session end)

    failed =
      results
      |> Enum.filter(&match?({:error, _}, &1))
      |> Enum.map(fn {:error, component} -> component.name end)

    {successful, failed}
  end

  defp log_failures([]), do: :ok

  defp log_failures(failed_components) do
    Logger.warning(
      "Partial session creation failure. Failed components: #{inspect(failed_components)}"
    )
  end

  defp validate_child_sessions_status(child_sessions) do
    active = filter_by_status(child_sessions, :active)
    failed = filter_by_status(child_sessions, :failed)
    cancelled = filter_by_status(child_sessions, :cancelled)

    case {active, failed, cancelled} do
      {[], [], []} ->
        :ok

      {[_ | _] = active, _, _} ->
        names = Enum.map(active, & &1.component.name) |> Enum.join(", ")
        {:error, "Child sessions still running: #{names}"}

      {_, [_ | _] = failed, _} ->
        details =
          Enum.map(failed, fn session ->
            "#{session.component.name} (reason: #{session.error_message || "unknown"})"
          end)
          |> Enum.join(", ")

        {:error, "Child sessions failed: #{details}"}

      {_, _, [_ | _] = cancelled} ->
        names = Enum.map(cancelled, & &1.component.name) |> Enum.join(", ")
        {:error, "Child sessions cancelled: #{names}"}
    end
  end

  defp filter_by_status(sessions, status) do
    Enum.filter(sessions, &(&1.status == status))
  end
end
