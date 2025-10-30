defmodule CodeMySpec.Repo.Migrations.AddSessionIdToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :session_id, references(:sessions, on_delete: :delete_all)
    end

    create index(:sessions, [:session_id])
  end
end
