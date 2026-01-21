defmodule CodeMySpecCli.Hooks do
  @moduledoc """
  Dispatcher for Claude Code hook handlers.

  Reads JSON from stdin, routes to the appropriate handler based on `hook_event_name`.

  ## Supported Hook Events

  - `Stop` - Always validates spec files via ValidateEdits, and additionally
    evaluates the agent task via EvaluateAgentTask if there's an active session
  - `SubagentStop` - Validates spec files edited during a subagent session
  - `PostToolUse` - Tracks file edits during agent sessions via TrackEdits

  ## Usage

      MIX_ENV=cli mix cli hook
  """

  require Logger

  alias CodeMySpec.Sessions
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

  defp dispatch(%{"hook_event_name" => "Stop", "session_id" => claude_session_id} = hook_input) do
    # Always run ValidateEdits
    validate_result = dispatch_validate_edits(hook_input)

    # Additionally run EvaluateAgentTask if there's an active session for this Claude session
    scope = Scope.for_cli()

    case Sessions.get_active_session_by_external_id(scope, claude_session_id) do
      %{id: session_id} = session ->
        Logger.info("[Hooks] Found active session #{session_id} for Claude session #{claude_session_id}")
        eval_result = EvaluateAgentTask.run(scope, %{session_id: session.id})
        # Merge results, prioritizing any blocking decision from validation
        merge_hook_results(validate_result, eval_result)

      nil ->
        Logger.info("[Hooks] No active session for Claude session #{claude_session_id}, only ValidateEdits ran")
        validate_result
    end
  end

  defp dispatch(%{"hook_event_name" => "Stop"} = hook_input) do
    # Stop without session_id - just run ValidateEdits
    Logger.warning("[Hooks] Stop hook without session_id in input")
    dispatch_validate_edits(hook_input)
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

  # Merge results from multiple hooks, prioritizing any blocking decisions
  defp merge_hook_results(result1, result2) do
    case {result1["decision"], result2["decision"]} do
      {"block", "block"} ->
        # Both block - combine reasons
        %{
          "decision" => "block",
          "reason" => "#{result1["reason"]}\n\n#{result2["reason"]}"
        }

      {"block", _} ->
        result1

      {_, "block"} ->
        result2

      _ ->
        # Neither blocks - merge maps
        Map.merge(result1, result2)
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
