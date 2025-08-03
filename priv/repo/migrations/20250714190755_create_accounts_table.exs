defmodule CodeMySpec.Repo.Migrations.CreateAccountsTable do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :name, :string, null: false
      add :slug, :string
      add :type, :string, null: false, default: "personal"

      timestamps()
    end

    create unique_index(:accounts, [:slug])
    create index(:accounts, [:type])
  end
end
