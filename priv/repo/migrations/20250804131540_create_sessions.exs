defmodule CodeMySpec.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions) do
      add :type, :string
      add :environment_id, :string
      add :status, :string
      add :state, :map
      add :project_id, references(:projects, on_delete: :nothing)
      add :account_id, references(:accounts, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:sessions, [:project_id])
    create index(:sessions, [:account_id])
  end
end
