defmodule CodeMySpecCli.Application do
  @impl true
  use Application

  def start(_type, _args) do
    ensure_db_directory()
    Application.ensure_all_started(:telemetry)

    children = [
      CodeMySpecCli.WebServer.Telemetry,
      # Registry for OAuth callback coordination
      {Registry, keys: :unique, name: CodeMySpecCli.Registry},
      # Finch HTTP client (required by Req)
      {Finch, name: Req.Finch},
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
