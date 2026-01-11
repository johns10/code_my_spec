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
        subcommands: [
          generate_component_spec: [
            name: "generate-component-spec",
            about: "Generate component specification prompt for Claude",
            args: [
              module_name: [
                value_name: "MODULE_NAME",
                help: "Component module name (e.g., 'MyApp.Accounts')",
                required: true,
                parser: :string
              ]
            ]
          ],
          validate_component_spec: [
            name: "validate-component-spec",
            about: "Validate generated component specification",
            args: [
              module_name: [
                value_name: "MODULE_NAME",
                help: "Component module name (e.g., 'MyApp.Accounts')",
                required: true,
                parser: :string
              ]
            ]
          ]
        ]
      )
      |> Optimus.parse!(argv)
      |> execute()
    end
  end

  defp execute(parsed) do
    case parsed do
      {[:generate_component_spec], %{args: args}} ->
        CodeMySpecCli.SlashCommands.GenerateComponentSpec.run(args)

      {[:validate_component_spec], %{args: args}} ->
        CodeMySpecCli.SlashCommands.ValidateComponentSpec.run(args)

      _ ->
        # No subcommand - launch TUI
        Ratatouille.run(CodeMySpecCli.Screens.Main, interval: 100)
    end
  end
end
