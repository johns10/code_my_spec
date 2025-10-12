defmodule CodeMySpec.Agents do
  @moduledoc """
  The Agents context for managing agent types and agent instances.
  """

  alias CodeMySpec.Agents.{Agent, AgentTypes}

  @doc """
  Creates an agent instance from an agent type.

  ## Examples
      iex> create_agent(:unit_coder, "my-coder", :claude_code, %{"model" => "claude-3-opus"})
      {:ok, %Agent{}}
  """
  def create_agent(agent_type_name, agent_name, implementation, config \\ %{}) do
    with {:ok, agent_type} <- AgentTypes.get(agent_type_name),
         attrs <- %{
           name: agent_name,
           agent_type: agent_type,
           implementation: implementation,
           config: config
         },
         changeset <- Agent.changeset(%Agent{}, attrs),
         {:ok, agent} <- Ecto.Changeset.apply_action(changeset, :insert) do
      {:ok, agent}
    end
  end

  @doc """
  Builds a command string using the agent's implementation (legacy API).
  Merges agent type config with instance config at runtime.
  Returns [command_string, pipe] tuple.
  """
  def build_command_string(%Agent{} = agent, prompt, opts \\ %{}) do
    implementation = get_impl(agent)
    implementation.build_command_string(agent, prompt, opts)
  end

  @doc """
  Builds a Command struct using the agent's implementation (new agentic API).
  Merges agent type config with instance config at runtime.
  Returns Command struct with command: "claude", metadata, and use_subprocess: false.

  The caller must set the module field on the returned command.
  """
  def build_command_struct(%Agent{} = agent, prompt, opts \\ %{}) do
    implementation = get_impl(agent)
    implementation.build_command_struct(agent, prompt, opts)
  end

  @doc """
  Gets the implementation module for an agent.
  """
  def get_impl(%Agent{implementation: implementation}), do: get_impl(implementation)
  def get_impl(:claude_code), do: CodeMySpec.Agents.Implementations.ClaudeCode

  @doc """
  Lists available agent types.
  """
  def list_agent_types, do: AgentTypes.list()

  @doc """
  Merges agent type config with instance config.
  Instance config takes precedence over agent type config.
  """
  def merge_configs(%Agent{agent_type: agent_type, config: instance_config}) do
    Map.merge(agent_type.config, instance_config)
  end
end
