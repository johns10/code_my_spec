defmodule CodeMySpec.Repo.Migrations.ChangeSessionsToUuid do
  use Ecto.Migration
  import Ecto.Query

  def up do
    # Drop foreign key constraints from tables that reference sessions
    drop constraint(:sessions, "sessions_session_id_fkey")
    drop constraint(:interactions, "interactions_session_id_fkey")

    # Drop indexes that reference session IDs
    drop_if_exists index(:sessions, [:session_id])
    drop_if_exists index(:interactions, [:session_id])
    drop_if_exists index(:interactions, [:session_id, :inserted_at])

    # Add new UUID columns
    alter table(:sessions) do
      add :new_id, :uuid
      add :new_session_id, :uuid
    end

    alter table(:interactions) do
      add :new_session_id, :uuid
    end

    # Generate UUIDs for existing sessions
    flush()

    repo = CodeMySpec.Repo

    # For each session, generate a UUID and store the mapping
    id_mapping =
      repo.all(
        from(s in "sessions",
          select: %{old_id: s.id}
        )
      )
      |> Enum.map(fn %{old_id: old_id} ->
        {old_id, Ecto.UUID.generate()}
      end)
      |> Map.new()

    # Update sessions with new UUIDs
    Enum.each(id_mapping, fn {old_id, new_uuid} ->
      {:ok, binary_uuid} = Ecto.UUID.dump(new_uuid)
      repo.query!(
        "UPDATE sessions SET new_id = $1 WHERE id = $2",
        [binary_uuid, old_id]
      )
    end)

    # Update session_id (parent session) references
    Enum.each(id_mapping, fn {old_id, new_uuid} ->
      {:ok, binary_uuid} = Ecto.UUID.dump(new_uuid)
      repo.query!(
        "UPDATE sessions SET new_session_id = $1 WHERE session_id = $2",
        [binary_uuid, old_id]
      )
    end)

    # Update interactions
    Enum.each(id_mapping, fn {old_id, new_uuid} ->
      {:ok, binary_uuid} = Ecto.UUID.dump(new_uuid)
      repo.query!(
        "UPDATE interactions SET new_session_id = $1 WHERE session_id = $2",
        [binary_uuid, old_id]
      )
    end)

    flush()

    # Drop old columns
    alter table(:sessions) do
      remove :id
      remove :session_id
    end

    alter table(:interactions) do
      remove :session_id
    end

    # Rename new columns to original names
    rename table(:sessions), :new_id, to: :id
    rename table(:sessions), :new_session_id, to: :session_id
    rename table(:interactions), :new_session_id, to: :session_id

    # Set sessions.id as primary key
    execute "ALTER TABLE sessions ADD PRIMARY KEY (id)"

    # Make interactions.session_id NOT NULL again
    execute "ALTER TABLE interactions ALTER COLUMN session_id SET NOT NULL"

    # Recreate foreign key constraints
    alter table(:sessions) do
      modify :session_id, references(:sessions, type: :uuid, on_delete: :delete_all)
    end

    alter table(:interactions) do
      modify :session_id, references(:sessions, type: :uuid, on_delete: :delete_all)
    end

    # Recreate indexes
    create index(:sessions, [:session_id])
    create index(:interactions, [:session_id])
    create index(:interactions, [:session_id, :inserted_at])
  end

  def down do
    raise "This migration cannot be safely reversed. UUID to integer conversion would lose data."
  end
end
