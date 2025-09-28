defmodule CodeMySpec.Agents.AgentBehaviour do
  @moduledoc """
  Defines the contract that all agent implementations must fulfill, ensuring consistent
  interface and behavior across different execution backends (Claude Code, OpenHands,
  custom agents, etc.). This behavior is for **implementations**, not agent types.
  """

  alias CodeMySpec.Agents.Agent

  @doc """
  Build a command for the agent with the given prompt and configuration.
  Returns the command that the client should execute.
  """
  @callback build_command(Agent.t(), prompt()) ::
              {:ok, command()} | {:error, execution_error()}

  @callback build_command(Agent.t(), prompt(), opts()) ::
              {:ok, command()} | {:error, execution_error()}

  @type prompt() :: String.t()
  @type command() :: [String.t()]
  @type config() :: map()
  @type opts() :: map()
  @type execution_error() :: atom()
  @type validation_error() :: String.t()
end
