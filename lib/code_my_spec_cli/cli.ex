defmodule CodeMySpecCli.CLI do
  @moduledoc """
  CLI argument parser using Optimus.

  Defines all commands and routes them to appropriate handlers.
  """

  def run(argv) do
    # If no arguments provided, launch the TUI
    if argv == [] do
      Ratatouille.run(CodeMySpecCli.Screens.Main, interval: 100)
    else
      Optimus.new!(
        name: "codemyspec",
        description: "AI-powered Phoenix code generation with proper architecture",
        version: "0.1.0",
        author: "CodeMySpec Team",
        about: "Generate production-quality Phoenix code using Claude Code orchestration",
        allow_unknown_args: false,
        parse_double_dash: true,
        subcommands: []
      )
      |> Optimus.parse!(argv)
      |> execute()
    end
  end

  defp execute(_parsed) do
    # Placeholder - just launch TUI for now
    Ratatouille.run(CodeMySpecCli.Screens.Main, interval: 100)
  end
end
