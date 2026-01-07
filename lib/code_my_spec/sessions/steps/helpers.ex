defmodule CodeMySpec.Sessions.Steps.Helpers do
  @moduledoc """
  Helper functions for step modules to reduce boilerplate and provide a stable API.

  This module centralizes common patterns in step implementations so that future changes
  to the orchestration layer don't require updating every single step module.
  """

  alias CodeMySpec.Agents

  @doc """
  Creates an agent and builds a command with session context.

  Automatically handles:
  - Creating the agent instance
  - Building the command with opts
  - Setting the module field on the command
  - Adding resume option if session has external_conversation_id

  The step is responsible for adding any step-specific options to opts before calling.

  ## Parameters
  - `step_module` - The step module (usually `__MODULE__`)
  - `session` - The session struct (used to check for external_conversation_id)
  - `agent_type` - Agent type atom (e.g., `:context_designer`)
  - `agent_name` - Agent instance name string
  - `prompt` - The prompt string to send to the agent
  - `opts` - Options keyword list (from orchestrator and/or added by step)

  ## Examples

      # With session
      Helpers.build_agent_command(
        __MODULE__,
        session,
        :context_designer,
        "context-design-generator",
        prompt,
        opts
      )
  """
  def build_agent_command(
        step_module,
        session,
        agent_type,
        agent_name,
        prompt,
        opts \\ []
      ) do
    opts = handle_opts(opts, session)

    with {:ok, agent} <- Agents.create_agent(agent_type, agent_name, :claude_code),
         {:ok, command} <- Agents.build_command_struct(agent, prompt, opts) do
      {:ok, Map.put(command, :module, step_module)}
    end
  end

  @doc """
  Builds a command using an existing agent instance with session context.

  Use this when you need to customize agent creation or reuse an agent.
  Also adds resume option if session has external_conversation_id.

  ## Examples

      with {:ok, agent} <- Agents.create_agent(:context_designer, "gen", :claude_code),
           {:ok, command} <- Helpers.build_command_with_agent(
             __MODULE__,
             session,
             agent,
             prompt,
             opts
           ) do
        {:ok, command}
      end
  """
  def build_command_with_agent(
        step_module,
        session,
        agent,
        prompt,
        opts \\ []
      ) do
    opts = handle_opts(opts, session)

    with {:ok, command} <- Agents.build_command_struct(agent, prompt, opts) do
      {:ok, Map.put(command, :module, step_module)}
    end
  end

  def handle_opts(opts, session),
    do:
      opts
      |> handle_resume_opts(session)
      |> handle_auto_opts(session)

  defp handle_resume_opts(opts, %{external_conversation_id: conversation_id})
       when not is_nil(conversation_id) do
    Keyword.put(opts, :resume, conversation_id)
  end

  defp handle_resume_opts(opts, _), do: opts

  defp handle_auto_opts(opts, %{execution_mode: :auto}) do
    Keyword.put(opts, :auto, true)
  end

  defp handle_auto_opts(opts, _), do: opts

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
      execution_strategy: :sync,
      metadata: %{},
      timestamp: DateTime.utc_now()
    }

    {:ok, command}
  end
end
