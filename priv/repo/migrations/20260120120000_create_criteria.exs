defmodule CodeMySpec.Repo.Migrations.CreateCriteria do
  use Ecto.Migration

  def change do
    create table(:criteria) do
      add :description, :text, null: false
      add :verified, :boolean, default: false, null: false
      add :verified_at, :utc_datetime
      add :story_id, references(:stories, on_delete: :delete_all), null: false
      add :project_id, references(:projects, type: :uuid, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, type: :id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:criteria, [:story_id])
    create index(:criteria, [:project_id])
    create index(:criteria, [:account_id])
  end
end
