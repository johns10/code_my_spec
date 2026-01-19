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
  @doc """
  Run evaluation and return the result map for hook output.
  Does not perform any IO - caller is responsible for output.
  """
  def run(scope, args) do
    session_id_arg = Map.get(args, :session_id)

    with {:ok, session_id} when not is_nil(session_id) <- resolve_session_id(session_id_arg),
         {:ok, session} <- get_session(scope, session_id),
         {:ok, task_session} <- build_task_session(session),
         {:ok, sync_result} <- sync_project(scope),
         result <- session.type.evaluate(scope, task_session) do
      output_sync_metrics(sync_result)
      format_result(result)
    else
      {:ok, nil} ->
        format_result({:ok, nil})

      {:error, reason} ->
        format_setup_error(reason)
    end
  rescue
    error ->
      IO.puts(:stderr, "Error: #{Exception.message(error)}")
      %{}
  end

  @doc """
  Execute evaluation with IO output. Legacy interface for direct CLI usage.
  """
  def execute(scope, args) do
    result = run(scope, args)
    IO.puts(Jason.encode!(result))
    :ok
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

  defp format_result({:ok, nil}), do: %{}

  defp format_result({:ok, :valid}) do
    CurrentSession.clear()
    IO.puts(:stderr, "All checks passed!")
    %{}
  end

  defp format_result({:ok, :invalid, feedback}) do
    %{"decision" => "block", "reason" => feedback}
  end

  defp format_result({:error, reason}) do
    IO.puts(:stderr, "Error: #{format_error(reason)}")
    %{}
  end

  defp format_setup_error(reason) do
    IO.puts(:stderr, "Setup error: #{format_error(reason)}")
    %{"decision" => "block", "reason" => format_error(reason)}
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
