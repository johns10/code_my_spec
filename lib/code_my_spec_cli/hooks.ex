defmodule CodeMySpecCli.Hooks do
  @moduledoc """
  Dispatcher for Claude Code hook handlers.

  Reads JSON from stdin, routes to the appropriate handler based on `hook_event_name`.

  ## Supported Hook Events

  - `Stop` - Routes based on active session:
    - If session exists: evaluates the agent task via EvaluateAgentTask
    - If no session: validates spec files tracked by FileEdits via ValidateEdits
  - `SubagentStop` - Validates spec files edited during a subagent session
  - `PostToolUse` - Tracks file edits during agent sessions via TrackEdits

  ## Usage

      MIX_ENV=cli mix cli hook
  """

  require Logger

  alias CodeMySpec.Sessions.CurrentSession
  alias CodeMySpec.Users.Scope
  alias CodeMySpecCli.Hooks.{TrackEdits, ValidateEdits}
  alias CodeMySpecCli.SlashCommands.EvaluateAgentTask

  @doc """
  Run a hook. Reads JSON from stdin, dispatches based on the hook_event_name.
  """
  @spec run() :: :ok
  def run do
    Logger.info("[Hooks] Hook invoked")

    raw_input = IO.read(:stdio, :eof)
    Logger.info("[Hooks] Raw stdin: #{inspect(raw_input)}")

    result =
      case parse_hook_input(raw_input) do
        {:ok, hook_input} ->
          Logger.info("[Hooks] Parsed input: #{inspect(hook_input)}")
          event_name = Map.get(hook_input, "hook_event_name", "unknown")
          {event_name, dispatch(hook_input)}

        {:error, reason} ->
          Logger.error("[Hooks] Parse error: #{reason}")
          {"parse_error", error_result(reason)}
      end

    handle_hook_output(result)
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
        EvaluateAgentTask.run(scope, %{})

      {:ok, nil} ->
        Logger.info("[Hooks] No active session, dispatching to ValidateEdits")
        dispatch_validate_edits(hook_input)
    end
  end

  defp dispatch(%{"hook_event_name" => "SubagentStop"} = hook_input) do
    dispatch_validate_edits(hook_input)
  end

  defp dispatch(%{"hook_event_name" => "PostToolUse"} = hook_input) do
    TrackEdits.run(hook_input)
  end

  defp dispatch(%{"hook_event_name" => event_name}) do
    Logger.warning("[Hooks] Unhandled hook event: #{inspect(event_name)}")
    %{}
  end

  defp dispatch(_hook_input) do
    error_result("Hook input missing hook_event_name")
  end

  defp dispatch_validate_edits(hook_input) do
    case Map.fetch(hook_input, "session_id") do
      {:ok, session_id} ->
        session_id
        |> ValidateEdits.run()
        |> ValidateEdits.format_output()

      :error ->
        Logger.warning("[Hooks] No session_id in hook input, skipping validation")
        %{}
    end
  end

  defp error_result(reason) when is_binary(reason) do
    %{"decision" => "block", "reason" => reason}
  end

  defp handle_hook_output({_event_name, result}) do
    IO.puts(Jason.encode!(result))
    :ok
  end
end
