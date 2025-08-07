defmodule CodeMySpec.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions) do
      add :type, :string
      add :agent, :string
      add :environment, :string
      add :status, :string
      add :state, :map
      add :interactions, :map
      add :project_id, references(:projects, on_delete: :nothing)
      add :account_id, references(:accounts, on_delete: :nothing)
      add :context_id, references(:components, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:sessions, [:project_id])
    create index(:sessions, [:account_id])
    create index(:sessions, [:context_id])
  end
end
