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
    # Start the application
    Mix.Task.run("app.start")

    # Run the main screen
    CodeMySpecCli.Screens.Main.show()
  end
end
