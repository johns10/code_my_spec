defmodule CodeMySpec.Agents.AgentTypes do
  alias CodeMySpec.Agents.AgentType

  @type agent_type() :: :unit_coder | :context_designer

  @spec get(agent_type()) :: {:ok, AgentType.t()} | {:error, :unknown_type}
  def get(agent_type) do
    case get_agent_type(agent_type) do
      nil -> {:error, :unknown_type}
      agent_type -> {:ok, agent_type}
    end
  end

  defp get_agent_type(:unit_coder) do
    %AgentType{
      name: "unit_coder",
      description: "A coding assistant specialized in writing individual components.",
      prompt:
        "You are an expert software developer assistant. Help with coding tasks, debugging, and implementation.",
      config: %{},
      additional_tools: []
    }
  end

  defp get_agent_type(:context_designer) do
    %AgentType{
      name: "context_designer",
      description: "Designs Phoenix contexts with proper architecture.",
      prompt: """
      You are a Phoenix context design expert. Generate comprehensive context designs that follow Phoenix conventions and best practices.

      Focus on:
      - Clean boundaries and responsibilities
      - Proper schema relationships
      - Public API design
      - Testing strategies
      """,
      config: %{},
      additional_tools: []
    }
  end

  defp get_agent_type(_), do: nil

  @spec list() :: [agent_type()]
  def list do
    [:unit_coder, :context_designer]
  end

  @spec exists?(agent_type()) :: boolean()
  def exists?(agent_type) do
    agent_type in list()
  end
end
