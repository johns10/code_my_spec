defmodule CodeMySpecCli.SlashCommands.EvaluateAgentTask do
  @moduledoc """
  Evaluate/validate an agent task session's output.

  Looks up the session by ID (from argument or persisted CurrentSession),
  determines its type, and calls the appropriate AgentTask module's evaluate/3
  function to validate Claude's output.

  ## Usage

  From CLI (typically called by stop hook):
      MIX_ENV=cli mix cli evaluate-agent-task
      MIX_ENV=cli mix cli evaluate-agent-task -s 123

  If no session ID is provided, reads from CurrentSession persistence.

  ## Output (JSON for hook decision control)

  Outputs JSON to stdout for Claude Code hook protocol:
  - If valid: `{}` (empty map allows Claude to stop), clears session
  - If invalid: `{"decision": "block", "reason": "<feedback>"}` (blocks Claude from stopping)
  - If error: `{}` (allows Claude to stop), error message to stderr
  """

  use CodeMySpecCli.SlashCommands.SlashCommandBehaviour

  alias CodeMySpec.Sessions
  alias CodeMySpec.Sessions.CurrentSession
  alias CodeMySpec.ProjectSync.Sync
  alias CodeMySpec.Requirements

  def execute(scope, args) do
    session_id_arg = Map.get(args, :session_id)

    with {:ok, session_id} when not is_nil(session_id) <- resolve_session_id(session_id_arg),
         {:ok, session} <- get_session(scope, session_id),
         {:ok, task_session} <- build_task_session(session),
         {:ok, sync_result} <- sync_project(scope),
         result <- session.type.evaluate(scope, task_session) do
      output_sync_metrics(sync_result)
      handle_result(result)
    else
      {:ok, nil} ->
        handle_result({:ok, nil})

      {:error, reason} ->
        # Block Claude and provide the error as feedback so it can fix the issue
        handle_setup_error(reason)
    end
  rescue
    error ->
      IO.puts(:stderr, "Error: #{Exception.message(error)}")
      {:error, Exception.message(error)}
  end

  defp resolve_session_id(nil) do
    # No argument provided, try to load from CurrentSession
    CurrentSession.get_session_id()
  end

  defp resolve_session_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} -> {:ok, int_id}
      _ -> {:error, "Invalid session ID: #{id}"}
    end
  end

  defp resolve_session_id(id) when is_integer(id), do: {:ok, id}

  defp get_session(scope, session_id) do
    case Sessions.get_session(scope, session_id) do
      nil -> {:error, "Session not found: #{session_id}"}
      session -> {:ok, session}
    end
  end

  defp build_task_session(session) do
    # Session should have component and project preloaded
    {:ok,
     %{
       component: session.component,
       project: session.project,
       environment: session.environment
     }}
  end

  defp handle_result({:ok, nil}) do
    :ok
  end

  defp handle_result({:ok, :valid}) do
    CurrentSession.clear()
    IO.puts(:stderr, "All checks passed!")
    # Empty map = no decision = Claude can stop
    IO.puts(Jason.encode!(%{}))
    :ok
  end

  defp handle_result({:ok, :invalid, feedback}) do
    # Output JSON to stdout to block Claude from stopping
    decision = %{"decision" => "block", "reason" => feedback}
    IO.puts(Jason.encode!(decision))
    :ok
  end

  defp handle_result({:error, reason}) do
    IO.puts(:stderr, "Error: #{format_error(reason)}")
    # Empty map = no decision = Claude can stop (even on error)
    IO.puts(Jason.encode!(%{}))
    {:error, reason}
  end

  defp handle_setup_error(reason) do
    # Setup errors (no session, session not found, etc.) should block Claude
    # and provide guidance on how to fix the issue
    IO.puts(:stderr, "Setup error: #{format_error(reason)}")
    decision = %{"decision" => "block", "reason" => format_error(reason)}
    IO.puts(Jason.encode!(decision))
    {:error, reason}
  end

  defp sync_project(scope) do
    # Clear all requirements before resyncing
    Requirements.clear_all_project_requirements(scope)

    case Sync.sync_all(scope) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, "Sync failed: #{inspect(reason)}"}
    end
  end

  defp output_sync_metrics(%{timings: timings}) do
    # Output to stderr since stdout is reserved for hook decision JSON
    IO.puts(
      :stderr,
      "Sync: contexts=#{timings.contexts_sync_ms}ms requirements=#{timings.requirements_sync_ms}ms total=#{timings.total_ms}ms"
    )
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(%Ecto.Changeset{} = changeset), do: inspect(changeset.errors)
  defp format_error(reason), do: inspect(reason)
end
