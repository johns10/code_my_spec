defmodule CodeMySpec.Sessions.Steps.Helpers do
  @moduledoc """
  Helper functions for step modules to reduce boilerplate and provide a stable API.

  This module centralizes common patterns in step implementations so that future changes
  to the orchestration layer don't require updating every single step module.
  """

  alias CodeMySpec.Agents

  @doc """
  Creates an agent and builds a command.

  Automatically handles:
  - Creating the agent instance
  - Building the command with opts
  - Setting the module field on the command

  The step is responsible for adding any step-specific options to opts before calling.

  ## Parameters
  - `step_module` - The step module (usually `__MODULE__`)
  - `agent_type` - Agent type atom (e.g., `:context_designer`)
  - `agent_name` - Agent instance name string
  - `prompt` - The prompt string to send to the agent
  - `opts` - Options keyword list (from orchestrator and/or added by step)

  ## Examples

      # Simple usage - just pass opts through
      Helpers.build_agent_command(
        __MODULE__,
        :context_designer,
        "context-design-generator",
        prompt,
        opts
      )

      # Step adds its own option
      opts_with_continue = Keyword.put(opts, :continue, true)
      Helpers.build_agent_command(
        __MODULE__,
        :context_designer,
        "context-design-reviser",
        prompt,
        opts_with_continue
      )
  """
  def build_agent_command(
        step_module,
        agent_type,
        agent_name,
        prompt,
        opts \\ []
      ) do
    with {:ok, agent} <- Agents.create_agent(agent_type, agent_name, :claude_code),
         {:ok, command} <- Agents.build_command_struct(agent, prompt, opts) do
      # Set the module field that orchestrator would normally set
      {:ok, Map.put(command, :module, step_module)}
    end
  end

  @doc """
  Builds a command using an existing agent instance.

  Use this when you need to customize agent creation or reuse an agent.

  ## Examples

      with {:ok, agent} <- Agents.create_agent(:context_designer, "gen", :claude_code),
           {:ok, command} <- Helpers.build_command_with_agent(
             __MODULE__,
             agent,
             prompt,
             [continue: true],
             opts
           ) do
        {:ok, command}
      end
  """
  def build_command_with_agent(
        step_module,
        agent,
        prompt,
        opts \\ []
      ) do
    with {:ok, command} <- Agents.build_command_struct(agent, prompt, opts) do
      {:ok, Map.put(command, :module, step_module)}
    end
  end

  @doc """
  Builds a simple shell command (non-agent).

  Use this for commands like `mix test` or `cat file.txt`.

  ## Examples

      Helpers.build_shell_command(__MODULE__, "mix test path/to/test.exs")
  """
  def build_shell_command(step_module, command_string) do
    command = %CodeMySpec.Sessions.Command{
      module: step_module,
      command: command_string,
      metadata: %{},
      timestamp: DateTime.utc_now()
    }

    {:ok, command}
  end
end
