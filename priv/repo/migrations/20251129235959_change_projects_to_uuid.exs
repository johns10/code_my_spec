defmodule CodeMySpec.Repo.Migrations.ChangeProjectsToUuid do
  use Ecto.Migration
  import Ecto.Query

  def up do
    # Drop unique indexes that reference project_id
    drop_if_exists unique_index(:components, [:module_name, :project_id])
    drop_if_exists unique_index(:components, [:module_name, :account_id])
    drop_if_exists unique_index(:stories, [:title, :project_id])

    # Drop foreign key constraints from tables that reference projects
    drop_if_exists constraint(:components, "components_project_id_fkey")
    drop_if_exists constraint(:stories, "stories_project_id_fkey")
    drop_if_exists constraint(:sessions, "sessions_project_id_fkey")
    drop_if_exists constraint(:content_admin, "content_admin_project_id_fkey")

    # Add new UUID columns to all tables
    alter table(:projects) do
      add :new_id, :uuid
    end

    alter table(:components) do
      add :new_project_id, :uuid
    end

    alter table(:stories) do
      add :new_project_id, :uuid
    end

    alter table(:sessions) do
      add :new_project_id, :uuid
    end

    alter table(:content_admin) do
      add :new_project_id, :uuid
    end

    alter table(:user_preferences) do
      add :new_active_project_id, :uuid
    end

    # Generate UUIDs for existing projects using Elixir code
    flush()

    repo = CodeMySpec.Repo

    # For each project, generate a UUID and store the mapping
    id_mapping =
      repo.all(
        from(p in "projects",
          select: %{old_id: p.id}
        )
      )
      |> Enum.map(fn %{old_id: old_id} ->
        {old_id, Ecto.UUID.generate()}
      end)
      |> Map.new()

    # Update projects with new UUIDs
    Enum.each(id_mapping, fn {old_id, new_uuid} ->
      {:ok, binary_uuid} = Ecto.UUID.dump(new_uuid)

      repo.query!(
        "UPDATE projects SET new_id = $1 WHERE id = $2",
        [binary_uuid, old_id]
      )
    end)

    # Update all referencing tables
    Enum.each(id_mapping, fn {old_id, new_uuid} ->
      {:ok, binary_uuid} = Ecto.UUID.dump(new_uuid)

      repo.query!(
        "UPDATE components SET new_project_id = $1 WHERE project_id = $2",
        [binary_uuid, old_id]
      )

      repo.query!(
        "UPDATE stories SET new_project_id = $1 WHERE project_id = $2",
        [binary_uuid, old_id]
      )

      repo.query!(
        "UPDATE sessions SET new_project_id = $1 WHERE project_id = $2",
        [binary_uuid, old_id]
      )

      repo.query!(
        "UPDATE content_admin SET new_project_id = $1 WHERE project_id = $2",
        [binary_uuid, old_id]
      )

      repo.query!(
        "UPDATE user_preferences SET new_active_project_id = $1 WHERE active_project_id = $2",
        [binary_uuid, old_id]
      )
    end)

    flush()

    # Drop old columns
    alter table(:projects) do
      remove :id
    end

    alter table(:components) do
      remove :project_id
    end

    alter table(:stories) do
      remove :project_id
    end

    alter table(:sessions) do
      remove :project_id
    end

    alter table(:content_admin) do
      remove :project_id
    end

    alter table(:user_preferences) do
      remove :active_project_id
    end

    # Rename new columns to original names
    rename table(:projects), :new_id, to: :id
    rename table(:components), :new_project_id, to: :project_id
    rename table(:stories), :new_project_id, to: :project_id
    rename table(:sessions), :new_project_id, to: :project_id
    rename table(:content_admin), :new_project_id, to: :project_id
    rename table(:user_preferences), :new_active_project_id, to: :active_project_id

    # Set projects.id as primary key
    execute "ALTER TABLE projects ADD PRIMARY KEY (id)"

    # Make columns NOT NULL where they should be
    execute "ALTER TABLE components ALTER COLUMN project_id SET NOT NULL"
    execute "ALTER TABLE content_admin ALTER COLUMN project_id SET NOT NULL"

    # Recreate foreign key constraints
    alter table(:components) do
      modify :project_id, references(:projects, type: :uuid, on_delete: :delete_all)
    end

    alter table(:stories) do
      modify :project_id, references(:projects, type: :uuid, on_delete: :delete_all)
    end

    alter table(:sessions) do
      modify :project_id, references(:projects, type: :uuid, on_delete: :nothing)
    end

    alter table(:content_admin) do
      modify :project_id, references(:projects, type: :uuid, on_delete: :delete_all)
    end

    # Recreate unique constraints
    create unique_index(:stories, [:title, :project_id])
    create unique_index(:components, [:module_name, :project_id])
  end

  def down do
    raise "This migration cannot be safely reversed. UUID to integer conversion would lose data."
  end
end
