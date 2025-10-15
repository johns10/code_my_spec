defmodule CodeMySpec.Repo.Migrations.CreateContentAdmin do
  use Ecto.Migration

  def change do
    create table(:content_admin) do
      add :content, :text
      add :processed_content, :text
      add :parse_status, :string, null: false
      add :parse_errors, :map
      add :metadata, :map

      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:content_admin, [:project_id])
    create index(:content_admin, [:account_id])
    create index(:content_admin, [:parse_status])
  end
end
