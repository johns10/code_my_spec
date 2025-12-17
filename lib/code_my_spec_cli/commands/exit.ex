defmodule CodeMySpecCli.Commands.Exit do
  @moduledoc """
  /exit command - exit the CLI
  """

  use CodeMySpecCli.Commands.CommandBehaviour

  @doc """
  Exit the CLI.
  """
  def execute(_scope, _args) do
    :exit
  end

  # Exit doesn't need scope
  def resolve_scope(_args), do: {:ok, nil}
end
