defmodule CodeMySpec.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :code_my_spec

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def import_data(file_path, opts \\ []) do
    load_app()
    Application.ensure_all_started(@app)
    CodeMySpec.Utils.Data.import_account(file_path, opts)
  end

  def export_data(account_id, file_path) do
    load_app()
    Application.ensure_all_started(@app)
    CodeMySpec.Utils.Data.export_account(account_id, file_path)
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
