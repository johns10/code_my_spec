defmodule CodeMySpec.Repo.Migrations.CreateContents do
  use Ecto.Migration

  def change do
    create table(:contents) do
      add :slug, :string, null: false
      add :content_type, :string, null: false
      add :raw_content, :text, null: false
      add :processed_content, :text
      add :protected, :boolean, default: false, null: false
      add :publish_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :parse_status, :string, default: "pending", null: false
      add :parse_errors, :map
      add :meta_title, :string
      add :meta_description, :string
      add :og_image, :string
      add :og_title, :string
      add :og_description, :string
      add :metadata, :map, default: %{}, null: false

      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:contents, [:project_id])
    create index(:contents, [:account_id])
    create index(:contents, [:content_type])
    create index(:contents, [:parse_status])
    create index(:contents, [:publish_at])
    create index(:contents, [:expires_at])

    create unique_index(:contents, [:slug, :content_type, :project_id],
             name: :contents_slug_content_type_project_id_index
           )
  end
end
