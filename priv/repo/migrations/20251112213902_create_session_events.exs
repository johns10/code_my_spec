defmodule CodeMySpec.Repo.Migrations.CreateSessionEvents do
  use Ecto.Migration

  def change do
    create table(:session_events) do
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :data, :map, null: false
      add :metadata, :map
      add :sent_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:session_events, [:session_id])
    create index(:session_events, [:session_id, :sent_at])
  end
end
