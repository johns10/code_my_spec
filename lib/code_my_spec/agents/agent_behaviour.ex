defmodule CodeMySpec.Agents.AgentBehaviour do
  @moduledoc """
  Defines the contract that all agent implementations must fulfill, ensuring consistent
  interface and behavior across different execution backends (Claude Code, OpenHands,
  custom agents, etc.). This behavior is for **implementations**, not agent types.
  """

  alias CodeMySpec.Agents.Agent

  @doc """
  Execute an agent with the given prompt and configuration.
  Streams output chunks to the provided handler function.
  """
  @callback execute(Agent.t(), prompt(), stream_handler()) ::
              {:ok, execution_result()} | {:error, execution_error()}

  @doc """
  Validate agent-specific configuration before agent creation.
  Returns validated config or list of validation errors.
  """
  @callback validate_config(config()) ::
              {:ok, config()} | {:error, [validation_error()]}

  @type prompt() :: String.t()
  @type stream_handler() :: (any() -> :ok)
  @type config() :: map()
  @type execution_result() :: map()
  @type execution_error() :: atom()
  @type validation_error() :: String.t()
end
