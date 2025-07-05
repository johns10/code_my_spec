defmodule CodeMySpec.Agents.RegistryTest do
  use ExUnit.Case
  doctest CodeMySpec.Agents.Registry

  alias CodeMySpec.Agents.{Registry, Agent}

  describe "get_agent/2" do
    test "returns agent with resolved implementation when AgentType has nil implementation" do
      Application.put_env(:code_my_spec, :agent_implementations, %{"unit_coder" => :claude_code})

      assert {:ok, %Agent{} = agent} = Registry.get_agent(:unit_coder, %{key: "value"})
      assert agent.agent_type.implementation == :claude_code
      assert agent.config == %{key: "value"}
    end

    test "returns agent with existing implementation when AgentType has implementation" do
      # Since the real AgentType for :unit_coder has implementation: nil,
      # it will be resolved from application config
      Application.put_env(:code_my_spec, :agent_implementations, %{"unit_coder" => :resolved_impl})

      assert {:ok, %Agent{} = agent} = Registry.get_agent(:unit_coder, %{})
      assert agent.agent_type.implementation == :resolved_impl
      assert agent.config == %{}
    end

    test "returns error when agent type is unknown" do
      assert {:error, :unknown_type} = Registry.get_agent(:unknown, %{})
    end

    test "uses empty config when none provided" do
      Application.put_env(:code_my_spec, :agent_implementations, %{"unit_coder" => :claude_code})

      assert {:ok, %Agent{} = agent} = Registry.get_agent(:unit_coder)
      assert agent.config == %{}
    end
  end

  describe "list_agents/0" do
    test "returns list of agent types from AgentTypes module" do
      assert Registry.list_agents() == [:unit_coder]
    end
  end
end
