defmodule CodeMySpecCli.Application do
  @impl true
  use Application
  # import Ratatouille.Constants, only: [key: 1]

  def start(_type, _args) do
    ensure_db_directory()
    Application.ensure_all_started(:telemetry)

    # Add file logger backend at runtime
    LoggerBackends.add({LoggerFileBackend, :file_log})

    children = [
      CodeMySpecCli.WebServer.Telemetry,
      CodeMySpec.Repo,
      CodeMySpec.Vault,
      CodeMySpecCli.Migrator,
      {Phoenix.PubSub, name: CodeMySpec.PubSub},
      # Registry for OAuth callback coordination
      {Registry, keys: :unique, name: CodeMySpecCli.Registry},
      # CodeMySpec.ProjectSync.FileWatcherServer,
      CodeMySpec.Sessions.InteractionRegistry,
      # Local web server for OAuth callbacks
      {CodeMySpecCli.WebServer, port: 8314}
    ]

    {:ok, supervisor} =
      Supervisor.start_link(children, strategy: :one_for_one, name: CodeMySpecCli.Supervisor)

    # Start the TUI after all services are running
    # This blocks until the user quits
    # Override quit_events to only use Ctrl+C, not 'q'
    # Ratatouille.run(CodeMySpecCli.Screens.Main,
    #   interval: 100,
    #   quit_events: [{:key, key(:ctrl_c)}]
    # )

    {:ok, supervisor}
  end

  defp ensure_db_directory do
    # Ensure ~/.codemyspec directory exists and touch the database file
    db_dir = Path.expand("~/.codemyspec")
    db_file = Path.join(db_dir, "cli.db")

    File.mkdir_p!(db_dir)

    # Touch the database file if it doesn't exist
    unless File.exists?(db_file) do
      File.write!(db_file, "")
    end
  end
end
