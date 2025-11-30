defmodule CodeMySpecCli.Migrator do
  @moduledoc """
  Simple Task that runs migrations on startup and then exits.
  """

  use Task

  def start_link(_arg) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run do
    # Run migrations automatically on startup
    migrations_path = Application.app_dir(:code_my_spec, "priv/repo/cli_migrations")
    Ecto.Migrator.run(CodeMySpec.Repo, migrations_path, :up, all: true)
  end
end
