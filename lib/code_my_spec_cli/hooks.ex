defmodule CodeMySpecCli.Hooks do
  @moduledoc """
  Dispatcher for Claude Code hook handlers.

  Reads JSON from stdin, routes to the appropriate handler based on `hook_event_name`.
  Each handler is responsible for its own stdout output.

  ## Supported Hook Events

  - `Stop` - Routes based on active session:
    - If session exists: evaluates the agent task via EvaluateAgentTask
    - If no session: validates spec files from transcript via ValidateEdits
  - `SubagentStop` - Validates spec files edited during a subagent session

  ## Usage

      MIX_ENV=cli mix cli hook
  """

  require Logger

  alias CodeMySpec.Sessions.CurrentSession
  alias CodeMySpec.Users.Scope
  alias CodeMySpecCli.Hooks.ValidateEdits
  alias CodeMySpecCli.SlashCommands.EvaluateAgentTask

  @doc """
  Run a hook. Reads JSON from stdin, dispatches based on hook_event_name.
  """
  @spec run() :: :ok
  def run do
    Logger.info("[Hooks] Hook invoked")

    raw_input = IO.read(:stdio, :eof)
    Logger.info("[Hooks] Raw stdin: #{inspect(raw_input)}")

    case parse_hook_input(raw_input) do
      {:ok, hook_input} ->
        Logger.info("[Hooks] Parsed input: #{inspect(hook_input)}")
        dispatch(hook_input)

      {:error, reason} ->
        Logger.error("[Hooks] Parse error: #{reason}")
        output_error(reason)
    end

    :ok
  end

  defp parse_hook_input(json_string) do
    case Jason.decode(json_string) do
      {:ok, hook_input} -> {:ok, hook_input}
      {:error, _reason} -> {:error, "Failed to parse hook input JSON"}
    end
  end

  defp dispatch(%{"hook_event_name" => "Stop"} = hook_input) do
    case CurrentSession.get_session_id() do
      {:ok, session_id} when not is_nil(session_id) ->
        Logger.info("[Hooks] Active session #{session_id}, dispatching to EvaluateAgentTask")
        scope = Scope.for_cli()
        EvaluateAgentTask.execute(scope, %{})

      {:ok, nil} ->
        Logger.info("[Hooks] No active session, dispatching to ValidateEdits")
        dispatch_validate_edits(hook_input, "transcript_path")
    end
  end

  defp dispatch(%{"hook_event_name" => "SubagentStop"} = hook_input) do
    dispatch_validate_edits(hook_input, "agent_transcript_path")
  end

  defp dispatch(%{"hook_event_name" => event_name}) do
    Logger.warning("[Hooks] Unhandled hook event: #{event_name}")
    # Unknown events pass through
    IO.puts("{}")
  end

  defp dispatch(_hook_input) do
    output_error("Hook input missing hook_event_name")
  end

  defp dispatch_validate_edits(hook_input, transcript_key) do
    case Map.fetch(hook_input, transcript_key) do
      {:ok, transcript_path} ->
        ValidateEdits.run_and_output(transcript_path)

      :error ->
        # No transcript path - pass through
        IO.puts("{}")
    end
  end

  defp output_error(reason) do
    IO.puts(Jason.encode!(%{"decision" => "block", "reason" => reason}))
  end
end
