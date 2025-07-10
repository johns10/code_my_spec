defmodule CodeMySpec.Agents.Implementations.ClaudeCode.CLIAdapterBehaviour do
  @moduledoc """
  Behavior for Claude CLI command execution implementations.
  """

  @callback run(command :: [String.t()], stream_handler :: (String.t() -> :ok)) ::
              {:ok, :completed} | {:error, reason :: atom(), details :: any()}
end
