defmodule Mix.Tasks.Cli do
  use Mix.Task

  @shortdoc "Run CodeMySpec CLI commands"

  def run(args) do
    # Set args in application env before starting
    Application.put_env(:code_my_spec, :cli_args, args)

    # Start the application - CliRunner will pick up args and execute
    Mix.Task.run("app.start", [])

    # Block until VM halts (CliRunner calls System.halt)
    Process.sleep(:infinity)
  end
end
