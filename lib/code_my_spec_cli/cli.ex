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
          start_agent_task: [
            name: "start-agent-task",
            about: "Start an agent task session and get the first prompt",
            options: [
              session_type: [
                value_name: "SESSION_TYPE",
                short: "-t",
                long: "--session-type",
                help: "Session type (e.g., 'component_spec')",
                required: true,
                parser: :string
              ],
              module_name: [
                value_name: "MODULE_NAME",
                short: "-m",
                long: "--module-name",
                help: "Component module name (e.g., 'MyApp.Accounts')",
                required: true,
                parser: :string
              ]
            ]
          ],
          evaluate_agent_task: [
            name: "evaluate-agent-task",
            about: "Evaluate/validate an agent task session's output",
            options: [
              session_id: [
                value_name: "SESSION_ID",
                short: "-s",
                long: "--session-id",
                help: "Session ID from start-agent-task",
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

      {[:start_agent_task], %{options: opts}} ->
        CodeMySpecCli.SlashCommands.StartAgentTask.run(opts)

      {[:evaluate_agent_task], %{options: opts}} ->
        CodeMySpecCli.SlashCommands.EvaluateAgentTask.run(opts)

      _ ->
        # No subcommand - launch TUI
        Ratatouille.run(CodeMySpecCli.Screens.Main, interval: 100)
    end
  end
end
