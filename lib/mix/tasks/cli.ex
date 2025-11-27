defmodule Mix.Tasks.Cli do
  @moduledoc """
  Runs the CodeMySpec CLI interface.

  ## Usage

      mix cli

  """
  @shortdoc "Launch the interactive CLI interface"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    # Start the CLI application - the REPL is automatically started as a supervised child
    {:ok, _} = CodeMySpecCli.Application.start(:normal, [])

  end
end
