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
  Builds a command using the agent's implementation.
  Merges agent type config with instance config at runtime.
  """
  def build_command(%Agent{} = agent, prompt) do
    implementation = get_impl(agent)
    implementation.build_command(agent, prompt)
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
