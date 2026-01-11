defmodule Mix.Tasks.Cli do
  use Mix.Task

  @shortdoc "CodeMySpec CLI"

  def run(args) do
    # Don't start the full application
    Mix.Task.run("app.start", [])

    # Call your CLI
    CodeMySpecCli.CLI.run(args)
  end
end
