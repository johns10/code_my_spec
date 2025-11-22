defmodule CodeMySpec.Agents.Implementations.ClaudeCode do
  @moduledoc """
  Claude Code CLI integration implementation of AgentBehaviour.

  Builds claude CLI commands with proper configuration for client execution.
  """

  alias CodeMySpec.Agents.Agent
  alias CodeMySpec.Sessions.Command

  @behaviour CodeMySpec.Agents.AgentBehaviour

  @impl true
  def build_command_string(%Agent{} = agent, prompt) do
    build_command_string(agent, prompt, %{})
  end

  @impl true
  def build_command_string(%Agent{} = agent, prompt, opts) do
    merged_config = CodeMySpec.Agents.merge_configs(agent)
    final_config = Map.merge(merged_config, opts)
    command_args = build_command_args(prompt, final_config)
    {:ok, command_args}
  end

  @doc """
  Builds a Command struct for Claude Code execution.

  Returns a Command with:
  - command: "claude"
  - args: List of CLI arguments
  - metadata: %{prompt: prompt, options: merged_config}

  The step module should be set by the caller.

  Accepts opts as either a keyword list or map.
  """
  @impl true
  def build_command_struct(%Agent{} = agent, prompt, opts \\ []) do
    merged_config = CodeMySpec.Agents.merge_configs(agent)
    # Convert keyword list to map if needed
    opts_map = if is_list(opts), do: Enum.into(opts, %{}), else: opts
    final_config = Map.merge(merged_config, opts_map)

    # Build CLI args using the same logic as build_command_string
    cli_args = build_cli_args(final_config)

    {:ok,
     %Command{
       # Caller should set this to their step module
       module: nil,
       command: "claude",
       metadata: %{
         prompt: prompt,
         args: cli_args,
         options: final_config
       },
       timestamp: DateTime.utc_now()
     }}
  end

  defp build_command_args(prompt, config) do
    base_cmd = ["claude"]
    cli_args = build_cli_args(config)
    base_cmd ++ cli_args ++ [prompt]
  end

  defp build_cli_args(config) do
    config
    |> Enum.flat_map(&format_cli_arg/1)
    |> Enum.reject(&is_nil/1)
  end

  defp format_cli_arg({"model", value}) when is_binary(value), do: ["--model", value]

  defp format_cli_arg({"max_turns", value}) when is_integer(value),
    do: ["--max-turns", to_string(value)]

  defp format_cli_arg({"system_prompt", value}) when is_binary(value),
    do: ["--system-prompt", value]

  defp format_cli_arg({"cwd", value}) when is_binary(value), do: ["--cwd", value]
  defp format_cli_arg({"verbose", true}), do: ["--verbose"]
  defp format_cli_arg({"verbose", false}), do: []

  defp format_cli_arg({"allowed_tools", tools}) when is_list(tools) do
    tools_str = Enum.join(tools, ",")
    ["--allowedTools", tools_str]
  end

  defp format_cli_arg({:resume, value}) when is_binary(value),
    do: format_cli_arg({"resume", value})

  defp format_cli_arg({"resume", value}) when is_binary(value), do: ["--resume", value]
  defp format_cli_arg({"continue", true}), do: ["--continue"]
  defp format_cli_arg({"continue", false}), do: []

  # Auto mode: uses dontAsk permission mode with whitelisted tools
  defp format_cli_arg({:auto, true}), do: format_cli_arg({"auto", true})

  defp format_cli_arg({"auto", true}) do
    [
      "--permission-mode",
      "dontAsk",
      "--allowedTools",
      "'Read,Write,Edit,Grep,Glob,WebFetch,WebSearch,Bash(mix:*)'"
    ]
  end

  defp format_cli_arg({"auto", false}), do: []

  # Allow explicit permission_mode override
  defp format_cli_arg({"permission_mode", value}) when is_binary(value),
    do: ["--permission-mode", value]

  defp format_cli_arg(_), do: []
end
