defmodule CodeMySpecCli.Hooks do
  @moduledoc """
  Dispatcher for Claude Code hook handlers.

  Reads JSON from stdin, routes to the appropriate handler based on `hook_event_name`,
  and outputs JSON to stdout.

  ## Supported Hook Events

  - `SubagentStop` - Validates spec files edited during a subagent session

  ## Usage

      MIX_ENV=cli mix cli hook
  """

  require Logger

  alias CodeMySpecCli.Hooks.ValidateEdits

  @doc """
  Run a hook. Reads JSON from stdin, dispatches based on hook_event_name, outputs JSON to stdout.
  """
  @spec run() :: :ok
  def run do
    Logger.info("[Hooks] Hook invoked")

    raw_input = IO.read(:stdio, :eof)
    Logger.info("[Hooks] Raw stdin: #{inspect(raw_input)}")

    parsed = parse_hook_input(raw_input)
    Logger.info("[Hooks] Parsed input: #{inspect(parsed)}")

    result = dispatch(parsed)
    Logger.info("[Hooks] Dispatch result: #{inspect(result)}")

    format_and_output(result)

    :ok
  end

  defp parse_hook_input(json_string) do
    case Jason.decode(json_string) do
      {:ok, hook_input} -> {:ok, hook_input}
      {:error, _reason} -> {:error, "Failed to parse hook input JSON"}
    end
  end

  defp dispatch({:error, reason}) do
    {:error, [reason]}
  end

  defp dispatch({:ok, %{"hook_event_name" => "SubagentStop"} = hook_input}) do
    case Map.fetch(hook_input, "agent_transcript_path") do
      {:ok, transcript_path} -> ValidateEdits.run(transcript_path)
      :error -> {:error, ["SubagentStop hook missing agent_transcript_path"]}
    end
  end

  defp dispatch({:ok, %{"hook_event_name" => event_name}}) do
    # Unknown hook events pass through (continue: true)
    {:ok, :valid}
    |> tap(fn _ -> IO.warn("Unhandled hook event: #{event_name}") end)
  end

  defp dispatch({:ok, _hook_input}) do
    {:error, ["Hook input missing hook_event_name"]}
  end

  defp format_and_output(result) do
    formatted = ValidateEdits.format_output(result)
    Logger.info("[Hooks] Formatted output: #{inspect(formatted)}")

    json = Jason.encode!(formatted)
    Logger.info("[Hooks] JSON output: #{json}")

    IO.puts(json)
  end
end