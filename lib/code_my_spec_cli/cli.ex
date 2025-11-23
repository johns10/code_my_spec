defmodule CodeMySpecCli.CLI do
  @moduledoc """
  CLI parser using Optimus

  Defines all available commands and routes to appropriate handlers.
  """

  def run(argv) do
    Optimus.new!(
      name: "codemyspec",
      description: "AI-powered Phoenix code generation with proper architecture",
      version: "0.1.0",
      author: "CodeMySpec Team",
      about: "Generate production-quality Phoenix code using Claude Code orchestration",
      allow_unknown_args: false,
      parse_double_dash: true,
      subcommands: [
        init: [
          name: "init",
          about: "Initialize CodeMySpec in current Phoenix project",
          flags: [
            force: [
              short: "-f",
              long: "--force",
              help: "Overwrite existing config"
            ]
          ]
        ],
        generate: [
          name: "generate",
          about: "Generate code from stories",
          args: [
            story_ids: [
              value_name: "STORY_IDS",
              help: "Comma-separated story IDs",
              required: false
            ]
          ],
          flags: [
            interactive: [
              short: "-i",
              long: "--interactive",
              help: "Launch interactive dashboard"
            ]
          ],
          options: [
            context: [
              short: "-c",
              long: "--context",
              help: "Target specific context",
              parser: :string
            ]
          ]
        ],
        dashboard: [
          name: "dashboard",
          about: "Launch session monitoring dashboard"
        ],
        session: [
          name: "session",
          about: "Manage Claude Code sessions",
          subcommands: [
            list: [name: "list", about: "List active sessions"],
            attach: [
              name: "attach",
              about: "Attach to session",
              args: [
                session_id: [
                  value_name: "SESSION_ID",
                  help: "Session ID to attach",
                  required: true
                ]
              ]
            ],
            kill: [
              name: "kill",
              about: "Kill session",
              args: [
                session_id: [
                  value_name: "SESSION_ID",
                  required: true
                ]
              ]
            ]
          ]
        ]
      ]
    )
    |> Optimus.parse!(argv)
    |> execute()
  end

  defp execute({[:init], %{flags: flags}}) do
    CodeMySpecCli.Commands.Init.run(flags)
  end

  defp execute({[:generate], %{args: args, flags: flags, options: opts}}) do
    CodeMySpecCli.Commands.Generate.run(args, Map.merge(flags, opts))
  end

  defp execute({[:dashboard], _}) do
    CodeMySpecCli.Commands.Dashboard.run()
  end

  defp execute({[:session, :list], _}) do
    CodeMySpecCli.Commands.Session.list()
  end

  defp execute({[:session, :attach], %{args: %{session_id: id}}}) do
    CodeMySpecCli.Commands.Session.attach(id)
  end

  defp execute({[:session, :kill], %{args: %{session_id: id}}}) do
    CodeMySpecCli.Commands.Session.kill(id)
  end
end
