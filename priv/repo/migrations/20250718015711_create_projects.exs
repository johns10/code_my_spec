defmodule CodeMySpec.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :name, :string
      add :description, :string
      add :code_repo, :string
      add :docs_repo, :string
      add :status, :string
      add :setup_error, :string
      add :account_id, references(:accounts, on_delete: :nothing)
      add :user_id, references(:users, type: :id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:projects, [:user_id])

    create index(:projects, [:account_id])
  end
end
