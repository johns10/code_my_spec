defmodule CodeMySpecCli do
  @moduledoc """
  Main entry point for the CodeMySpec CLI application.
  """

  alias CodeMySpecCli.Cli

  @doc """
  Main entry point for the CLI.
  """
  def main(args) do
    Cli.run(args)
  end
end
