defmodule CodeMySpecCli.Application do
  @impl true
  use Application

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
      # File watcher for automatic project sync
      CodeMySpec.ProjectSync.FileWatcherServer,
      # Job status component for UI
      CodeMySpecCli.Components.JobStatus,
      # Local HTTP server for OAuth callbacks and Anthropic proxying
      {CodeMySpecCli.WebServer, port: 8314},
      # The REPL interface
      CodeMySpecCli.Cli.TuiServer
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: CodeMySpecCli.Supervisor)
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
