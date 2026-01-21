defmodule CodeMySpecCli.Cli do
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
          login: [
            name: "login",
            about: "Authenticate with the CodeMySpec server via OAuth2"
          ],
          logout: [
            name: "logout",
            about: "Clear stored authentication credentials"
          ],
          whoami: [
            name: "whoami",
            about: "Show current authenticated user (triggers token refresh if expired)"
          ],
          start_agent_task: [
            name: "start-agent-task",
            about: "Start an agent task session and get the first prompt",
            options: [
              external_id: [
                value_name: "EXTERNAL_ID",
                short: "-e",
                long: "--external-id",
                help: "Claude session ID (from ${CLAUDE_SESSION_ID} in skills)",
                required: true,
                parser: :string
              ],
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
          ],
          evaluate_agent_task: [
            name: "evaluate-agent-task",
            about: "Evaluate/validate an agent task session's output"
          ],
          hook: [
            name: "hook",
            about:
              "Run a Claude Code hook handler (reads JSON from stdin, routes by hook_event_name, outputs JSON)"
          ]
        ]
      )
      |> Optimus.parse!(argv)
      |> execute()
    end
  end

  defp run_login do
    alias CodeMySpecCli.Auth.OAuthClient

    IO.puts("Opening browser for authentication...")
    IO.puts("Waiting for OAuth callback...")

    case OAuthClient.authenticate() do
      {:ok, _token_data} ->
        IO.puts("Successfully authenticated!")

      {:error, reason} ->
        IO.puts(:stderr, "Authentication failed: #{reason}")
        System.halt(1)
    end
  end

  defp run_logout do
    alias CodeMySpecCli.Auth.OAuthClient

    case OAuthClient.logout() do
      :ok ->
        IO.puts("Successfully logged out.")
    end
  end

  defp run_whoami do
    alias CodeMySpecCli.Auth.OAuthClient

    IO.puts("Checking authentication (will refresh token if expired)...")

    case OAuthClient.get_token() do
      {:ok, _token} ->
        case CodeMySpecCli.Config.get_current_user_email() do
          {:ok, email} ->
            IO.puts("Authenticated as: #{email}")

          {:error, _} ->
            IO.puts("Authenticated (but no email stored)")
        end

      {:error, :not_authenticated} ->
        IO.puts(:stderr, "Not authenticated. Run: mix cli login")
        System.halt(1)

      {:error, :needs_authentication} ->
        IO.puts(:stderr, "Token expired and refresh failed. Run: mix cli login")
        System.halt(1)
    end
  end

  defp execute(parsed) do
    case parsed do
      {[:login], _} ->
        run_login()

      {[:logout], _} ->
        run_logout()

      {[:whoami], _} ->
        run_whoami()

      {[:start_agent_task], %{options: opts}} ->
        CodeMySpecCli.SlashCommands.StartAgentTask.run(opts)

      {[:evaluate_agent_task], %{options: opts}} ->
        CodeMySpecCli.SlashCommands.EvaluateAgentTask.run(opts)

      {[:hook], _} ->
        CodeMySpecCli.Hooks.run()

      _ ->
        # No subcommand - launch TUI
        Ratatouille.run(CodeMySpecCli.Screens.Main, interval: 100)
    end
  end
end
