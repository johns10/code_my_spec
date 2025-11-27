defmodule CodeMySpecCli.Commands.Exit do
  @moduledoc """
  /exit command - exit the CLI
  """

  @behaviour CodeMySpecCli.Commands.CommandBehaviour

  @doc """
  Exit the CLI.
  """
  def execute(_args) do
    Owl.IO.puts(["\n", Owl.Data.tag("Goodbye! 👋", :green)])
    :exit
  end
end
