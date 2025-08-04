defmodule CodeMySpec.Repo.Migrations.CreateRules do
  use Ecto.Migration

  def change do
    create table(:rules) do
      add :name, :string
      add :content, :text
      add :component_type, :string
      add :session_type, :string
      add :account_id, references(:accounts, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:rules, [:account_id])
  end
end
