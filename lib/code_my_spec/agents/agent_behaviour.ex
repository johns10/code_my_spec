defmodule CodeMySpec.Agents.AgentBehaviour do
  @moduledoc """
  Defines the contract that all agent implementations must fulfill, ensuring consistent
  interface and behavior across different execution backends (Claude Code, OpenHands,
  custom agents, etc.). This behavior is for **implementations**, not agent types.
  """

  alias CodeMySpec.Agents.Agent

  alias CodeMySpec.Sessions.Command

  @doc """
  Build a command string for the agent with the given prompt and configuration.
  Returns the command string that the client should execute.
  Legacy API - returns [command_string, pipe] tuple.
  """
  @callback build_command_string(Agent.t(), prompt()) ::
              {:ok, command_list()} | {:error, execution_error()}

  @callback build_command_string(Agent.t(), prompt(), opts()) ::
              {:ok, command_list()} | {:error, execution_error()}

  @doc """
  Build a Command struct for the agent with the given prompt and configuration.
  Returns a Command struct for agentic execution (module field must be set by caller).
  """
  @callback build_command_struct(Agent.t(), prompt(), opts()) ::
              {:ok, Command.t()} | {:error, execution_error()}

  @type prompt() :: String.t()
  @type command_list() :: [String.t()]
  @type config() :: map()
  @type opts() :: map() | keyword()
  @type execution_error() :: atom()
  @type validation_error() :: String.t()
end
