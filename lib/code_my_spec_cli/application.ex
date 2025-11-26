defmodule CodeMySpecCli.Application do
  @impl true
  use Application

  def start(_type, _args) do
    IO.puts("start")
    # Get command-line arguments from Burrito
    args = Burrito.Util.Args.get_arguments()

    # Start required services
    ensure_db_directory()

    # Start supervisor for background services
    children = []

    IO.puts("after ensure all started")

    result =
      Supervisor.start_link(children, strategy: :one_for_one, name: CodeMySpecCli.Supervisor)

    IO.inspect(result)

    # Run the CLI (this blocks until CLI completes)
    CodeMySpecCli.main(args)

    IO.puts("after main")

    # Exit when CLI is done
    result
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
