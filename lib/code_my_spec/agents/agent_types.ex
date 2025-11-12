defmodule CodeMySpec.Agents.AgentTypes do
  alias CodeMySpec.Agents.AgentType

  @type agent_type() ::
          :unit_coder | :context_designer | :context_reviewer | :component_designer | :test_writer

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
      - Well defined components
      - Proper schema relationships
      - Public API design
      - Testing strategies
      """,
      config: %{},
      additional_tools: []
    }
  end

  defp get_agent_type(:context_reviewer) do
    %AgentType{
      name: "context_reviewer",
      description:
        "Reviews Phoenix context designs and child component designs for architectural consistency.",
      prompt: """
      You are a Phoenix context design reviewer. Perform comprehensive architectural reviews of context designs and their child components.

      Focus on:
      - Architectural consistency and Phoenix best practices
      - Integration between context and child components
      - Alignment with user stories and requirements
      - Identifying and fixing design issues
      - Writing comprehensive review documentation
      """,
      config: %{},
      additional_tools: []
    }
  end

  defp get_agent_type(:component_designer) do
    %AgentType{
      name: "component_designer",
      description: "Designs components of Phoenix contexts.",
      prompt: """
      You are a Phoenix component designer. Design simple, clear, readable components that satisfy requirements.

      Focus on:
      - Clarity of purpose and boundaries
      - Testability
      - Simplicity of design
      - Only designing necessary functionality
      """,
      config: %{},
      additional_tools: []
    }
  end

  defp get_agent_type(:test_writer) do
    %AgentType{
      name: "test_writer",
      description: "Writes tests and fixtures for Phoenix components.",
      prompt: """
      You are a Phoenix test writer. Generate comprehensive tests and fixtures for components.

      Focus on:
      - Testing all public API functions
      - Testing edge cases and error conditions
      - Creating reusable fixture functions
      - Following test organization patterns
      - Testing proper scoping and access patterns
      - Clear, maintainable test code
      """,
      config: %{},
      additional_tools: []
    }
  end

  defp get_agent_type(_), do: nil

  @spec list() :: [agent_type()]
  def list do
    [:unit_coder, :context_designer, :context_reviewer, :component_designer, :test_writer]
  end

  @spec exists?(agent_type()) :: boolean()
  def exists?(agent_type) do
    agent_type in list()
  end
end
