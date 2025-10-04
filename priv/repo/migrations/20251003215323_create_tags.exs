defmodule CodeMySpec.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :project_id, references(:projects, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tags, [:slug, :project_id, :account_id],
             name: :tags_slug_project_id_account_id_index
           )

    create index(:tags, [:account_id])
    create index(:tags, [:project_id])
  end
end
