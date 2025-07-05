defmodule CodeMySpec.Agents.Registry do
  @moduledoc """
  Agent factory that creates Agent structs with embedded AgentType information.
  Handles implementation resolution when AgentType doesn't specify one.
  """

  alias CodeMySpec.Agents.{Agent, AgentType, AgentTypes}

  @type agent_type() :: :unit_coder

  @spec get_agent(agent_type(), map()) :: {:ok, Agent.t()} | {:error, :unknown_type}
  def get_agent(type, config \\ %{}) do
    case AgentTypes.get(type) do
      {:ok, agent_type} ->
        resolved_agent_type = resolve_implementation(agent_type)

        agent = %Agent{
          agent_type: resolved_agent_type,
          config: config
        }

        {:ok, agent}

      {:error, :unknown_type} ->
        {:error, :unknown_type}
    end
  end

  @spec list_agents() :: [agent_type()]
  def list_agents do
    AgentTypes.list()
  end

  defp resolve_implementation(%AgentType{implementation: nil} = agent_type) do
    implementations = Application.get_env(:code_my_spec, :agent_implementations, %{})
    resolved_implementation = Map.get(implementations, agent_type.name)
    %{agent_type | implementation: resolved_implementation}
  end
end
