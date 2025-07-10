defmodule CodeMySpec.Agents.Implementations.ClaudeCode do
  @moduledoc """
  Claude Code CLI integration implementation of AgentBehaviour.

  Orchestrates configuration merging, command building, and streaming execution
  for the Claude Code CLI tool.
  """

  alias CodeMySpec.Agents.{Agent, AgentType}

  @behaviour CodeMySpec.Agents.AgentBehaviour

  @impl true
  def execute(%Agent{} = agent, prompt, stream_handler) do
    with merged_config <- merge_configs(agent),
         command_args <- build_command(prompt, merged_config),
         cli_adapter <- get_cli_adapter() do
      case cli_adapter.run(command_args, stream_handler) do
        {:ok, :completed} ->
          {:ok, %{status: :completed}}

        {:error, reason, _details} ->
          {:error, reason}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp merge_configs(%Agent{config: agent_config, agent_type: %AgentType{config: type_config}}) do
    Map.merge(type_config, agent_config)
  end

  @spec build_command(any(), any()) :: [...]
  def build_command(prompt, config) do
    base_cmd = ["claude", "--output-format", "stream-json", "--print", prompt]
    cli_args = build_cli_args(config)
    base_cmd ++ cli_args
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

  defp format_cli_arg(_), do: []

  defp get_cli_adapter do
    Application.get_env(
      :code_my_spec,
      :claude_cli_adapter,
      CodeMySpec.Agents.Implementations.ClaudeCode.CLIAdapter
    )
  end
end
