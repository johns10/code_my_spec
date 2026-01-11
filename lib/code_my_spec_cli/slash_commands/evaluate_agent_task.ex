defmodule CodeMySpecCli.SlashCommands.EvaluateAgentTask do
  @moduledoc """
  Evaluate/validate an agent task session's output.

  Looks up the session by ID, determines its type, and calls the appropriate
  AgentTask module's evaluate/3 function to validate Claude's output.

  ## Usage

  From CLI (typically called by stop hook):
      MIX_ENV=cli mix cli evaluate-agent-task -s 123

  ## Output

  - If valid: Success message, exits 0
  - If invalid: Validation errors for Claude to fix, exits 1
  - If error: Error message, exits 1
  """

  use CodeMySpecCli.SlashCommands.SlashCommandBehaviour

  alias CodeMySpec.Sessions
  alias CodeMySpec.Sessions.AgentTasks

  # Maps session type modules to their AgentTask modules
  @session_type_map %{
    CodeMySpec.ComponentSpecSessions => AgentTasks.ComponentSpec
    # Add more as they're implemented:
    # CodeMySpec.ComponentCodingSessions => AgentTasks.ComponentCoding,
  }

  def execute(scope, args) do
    session_id = Map.get(args, :session_id)

    with {:ok, session_id} <- parse_session_id(session_id),
         {:ok, session} <- get_session(scope, session_id),
         {:ok, agent_task_module} <- resolve_agent_task(session.type),
         {:ok, task_session} <- build_task_session(session),
         result <- agent_task_module.evaluate(scope, task_session) do
      handle_result(result)
    else
      {:error, reason} ->
        output_error(reason)
        {:error, reason}
    end
  rescue
    error ->
      output_error(Exception.message(error))
      {:error, Exception.message(error)}
  end

  defp parse_session_id(nil) do
    {:error, "Session ID is required. Use -s or --session-id"}
  end

  defp parse_session_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} -> {:ok, int_id}
      _ -> {:error, "Invalid session ID: #{id}"}
    end
  end

  defp parse_session_id(id) when is_integer(id), do: {:ok, id}

  defp get_session(scope, session_id) do
    case Sessions.get_session(scope, session_id) do
      nil -> {:error, "Session not found: #{session_id}"}
      session -> {:ok, session}
    end
  end

  defp resolve_agent_task(session_type) do
    case Map.get(@session_type_map, session_type) do
      nil -> {:error, "No AgentTask module for session type: #{inspect(session_type)}"}
      module -> {:ok, module}
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

  defp handle_result({:ok, :valid}) do
    IO.puts(":::STATUS:::")
    IO.puts("valid")
    IO.puts(":::MESSAGE:::")
    IO.puts("Component specification is valid!")
    :ok
  end

  defp handle_result({:ok, :invalid, feedback}) do
    IO.puts(":::STATUS:::")
    IO.puts("invalid")
    IO.puts(":::FEEDBACK:::")
    IO.puts("<<<FEEDBACK_START")
    IO.puts(feedback)
    IO.puts(">>>FEEDBACK_END")
    {:error, "validation_failed"}
  end

  defp handle_result({:error, reason}) do
    output_error(reason)
    {:error, reason}
  end

  defp output_error(reason) do
    IO.puts(":::STATUS:::")
    IO.puts("error")
    IO.puts(":::ERROR:::")
    IO.puts("<<<ERROR_START")
    IO.puts(format_error(reason))
    IO.puts(">>>ERROR_END")
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(%Ecto.Changeset{} = changeset), do: inspect(changeset.errors)
  defp format_error(reason), do: inspect(reason)
end
