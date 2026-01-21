defmodule CodeMySpecCli.SlashCommands.EvaluateAgentTask do
  @moduledoc """
  Evaluate/validate an agent task session's output.

  Looks up the session by ID (passed from the Stop hook via external_conversation_id lookup),
  determines its type, and calls the appropriate AgentTask module's evaluate/3
  function to validate Claude's output.

  ## Usage

  Typically called by the Stop hook, which looks up the session by Claude's session ID
  and passes the internal session ID.

  ## Output (JSON for hook decision control)

  Outputs JSON to stdout for Claude Code hook protocol:
  - If valid: `{}` (empty map allows Claude to stop), marks session complete
  - If invalid: `{"decision": "block", "reason": "<feedback>"}` (blocks Claude from stopping)
  - If error: `{}` (allows Claude to stop), error message to stderr
  """

  use CodeMySpecCli.SlashCommands.SlashCommandBehaviour

  alias CodeMySpec.Sessions
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
         :ok <- check_session_active(session),
         {:ok, task_session} <- build_task_session(session),
         {:ok, sync_result} <- sync_project(scope),
         result <- session.type.evaluate(scope, task_session) do
      output_sync_metrics(sync_result)
      maybe_complete_session(scope, session, result)
      format_result(result)
    else
      {:ok, nil} ->
        format_result({:ok, nil})

      {:ok, {:already_closed, status}} ->
        IO.puts(:stderr, "Session already #{status}, skipping evaluation")
        %{}

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

  defp resolve_session_id(nil), do: {:ok, nil}
  defp resolve_session_id(id) when is_binary(id), do: {:ok, id}

  defp get_session(scope, session_id) do
    case Sessions.get_session(scope, session_id) do
      nil -> {:error, "Session not found: #{session_id}"}
      session -> {:ok, session}
    end
  end

  defp check_session_active(%{status: :active}), do: :ok
  defp check_session_active(%{status: status}), do: {:ok, {:already_closed, status}}

  defp maybe_complete_session(scope, session, {:ok, :valid}) do
    Sessions.update_session(scope, session, %{status: :complete})
  end

  defp maybe_complete_session(_scope, _session, _result), do: :ok

  defp build_task_session(session) do
    # Session should have component and project preloaded
    {:ok,
     %{
       external_id: session.external_conversation_id,
       component: session.component,
       project: session.project,
       environment: session.environment
     }}
  end

  defp format_result({:ok, nil}), do: %{}

  defp format_result({:ok, :valid}) do
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
