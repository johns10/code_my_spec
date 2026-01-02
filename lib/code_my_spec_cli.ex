defmodule CodeMySpecCli do
  @moduledoc """
  Main entry point for the CodeMySpec CLI application.
  """

  alias CodeMySpecCli.CLI

  @doc """
  Main entry point called from the Application module.
  """
  def main(args) do
    # Parse arguments and run CLI
    CLI.run(args)
  end
end
