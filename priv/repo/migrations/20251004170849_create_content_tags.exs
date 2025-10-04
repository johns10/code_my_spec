defmodule CodeMySpec.Repo.Migrations.CreateContentTags do
  use Ecto.Migration

  def change do
    create table(:content_tags) do
      add :content_id, references(:contents, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:content_tags, [:content_id])
    create index(:content_tags, [:tag_id])
    create unique_index(:content_tags, [:content_id, :tag_id])
  end
end
