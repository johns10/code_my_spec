defmodule CodeMySpec.Repo.Migrations.CreateStories do
  use Ecto.Migration

  def change do
    create table(:stories) do
      add :title, :string
      add :description, :text
      add :acceptance_criteria, {:array, :string}
      add :priority, :integer
      add :status, :string
      add :locked_at, :utc_datetime
      add :lock_expires_at, :utc_datetime
      add :locked_by, references(:users, on_delete: :nothing)
      add :project_id, references(:projects, on_delete: :nothing)
      add :account_id, references(:accounts, type: :id, on_delete: :delete_all)
      add :first_version_id, references(:versions), null: false
      add :current_version_id, references(:versions), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:stories, [:account_id])

    create index(:stories, [:locked_by])
    create index(:stories, [:project_id])
    create unique_index(:stories, [:first_version_id])
    create unique_index(:stories, [:current_version_id])
  end
end
