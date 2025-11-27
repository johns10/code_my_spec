defmodule CodeMySpecCli.Commands.CommandBehaviour do
  @moduledoc """
  Behavior for CLI commands.

  All commands must implement:
  - execute/1 - executes the command with arguments

  The command name is automatically derived from the module name.
  For example: CodeMySpecCli.Commands.Login -> "login"
  """

  @callback execute(args :: [String.t()]) :: :ok | :exit | {:error, String.t()}
end
