defmodule CodeMySpec.Repo.Migrations.ChangeComponentsToUuid do
  use Ecto.Migration
  import Ecto.Query

  def up do
    # Drop foreign key constraints from tables that reference components
    drop constraint(:components, "components_parent_component_id_fkey")
    drop constraint(:dependencies, "dependencies_source_component_id_fkey")
    drop constraint(:dependencies, "dependencies_target_component_id_fkey")
    drop constraint(:similar_components, "similar_components_component_id_fkey")
    drop constraint(:similar_components, "similar_components_similar_component_id_fkey")
    drop constraint(:stories, "stories_component_id_fkey")
    drop constraint(:requirements, "requirements_component_id_fkey")
    drop constraint(:sessions, "sessions_component_id_fkey")

    # Drop indexes that reference component IDs
    drop_if_exists index(:components, [:parent_component_id])
    drop_if_exists index(:dependencies, [:source_component_id])
    drop_if_exists index(:dependencies, [:target_component_id])
    drop_if_exists index(:dependencies, [:source_component_id, :target_component_id])
    drop_if_exists index(:similar_components, [:component_id])
    drop_if_exists index(:similar_components, [:similar_component_id])
    drop_if_exists index(:similar_components, [:component_id, :similar_component_id])
    drop_if_exists index(:stories, [:component_id])
    drop_if_exists index(:requirements, [:component_id])
    drop_if_exists index(:requirements, [:component_id, :name])
    drop_if_exists index(:sessions, [:component_id])

    # Add new UUID columns to all tables
    alter table(:components) do
      add :new_id, :uuid
      add :new_parent_component_id, :uuid
    end

    alter table(:dependencies) do
      add :new_source_component_id, :uuid
      add :new_target_component_id, :uuid
    end

    alter table(:similar_components) do
      add :new_component_id, :uuid
      add :new_similar_component_id, :uuid
    end

    alter table(:stories) do
      add :new_component_id, :uuid
    end

    alter table(:requirements) do
      add :new_component_id, :uuid
    end

    alter table(:sessions) do
      add :new_component_id, :uuid
    end

    # Generate UUIDs for existing components using Elixir code
    flush()

    # We'll use a simpler approach - just generate new UUIDs in Elixir
    repo = CodeMySpec.Repo

    # For each component, generate a UUID and store the mapping
    id_mapping =
      repo.all(
        from(c in "components",
          select: %{old_id: c.id}
        )
      )
      |> Enum.map(fn %{old_id: old_id} ->
        {old_id, Ecto.UUID.generate()}
      end)
      |> Map.new()

    # Update components with new UUIDs
    Enum.each(id_mapping, fn {old_id, new_uuid} ->
      {:ok, binary_uuid} = Ecto.UUID.dump(new_uuid)

      repo.query!(
        "UPDATE components SET new_id = $1 WHERE id = $2",
        [binary_uuid, old_id]
      )
    end)

    # Update parent_component_id references
    Enum.each(id_mapping, fn {old_id, new_uuid} ->
      {:ok, binary_uuid} = Ecto.UUID.dump(new_uuid)

      repo.query!(
        "UPDATE components SET new_parent_component_id = $1 WHERE parent_component_id = $2",
        [binary_uuid, old_id]
      )
    end)

    # Update dependencies
    Enum.each(id_mapping, fn {old_id, new_uuid} ->
      {:ok, binary_uuid} = Ecto.UUID.dump(new_uuid)

      repo.query!(
        "UPDATE dependencies SET new_source_component_id = $1 WHERE source_component_id = $2",
        [binary_uuid, old_id]
      )

      repo.query!(
        "UPDATE dependencies SET new_target_component_id = $1 WHERE target_component_id = $2",
        [binary_uuid, old_id]
      )
    end)

    # Update similar_components
    Enum.each(id_mapping, fn {old_id, new_uuid} ->
      {:ok, binary_uuid} = Ecto.UUID.dump(new_uuid)

      repo.query!(
        "UPDATE similar_components SET new_component_id = $1 WHERE component_id = $2",
        [binary_uuid, old_id]
      )

      repo.query!(
        "UPDATE similar_components SET new_similar_component_id = $1 WHERE similar_component_id = $2",
        [binary_uuid, old_id]
      )
    end)

    # Update stories
    Enum.each(id_mapping, fn {old_id, new_uuid} ->
      {:ok, binary_uuid} = Ecto.UUID.dump(new_uuid)

      repo.query!(
        "UPDATE stories SET new_component_id = $1 WHERE component_id = $2",
        [binary_uuid, old_id]
      )
    end)

    # Update requirements
    Enum.each(id_mapping, fn {old_id, new_uuid} ->
      {:ok, binary_uuid} = Ecto.UUID.dump(new_uuid)

      repo.query!(
        "UPDATE requirements SET new_component_id = $1 WHERE component_id = $2",
        [binary_uuid, old_id]
      )
    end)

    # Update sessions
    Enum.each(id_mapping, fn {old_id, new_uuid} ->
      {:ok, binary_uuid} = Ecto.UUID.dump(new_uuid)

      repo.query!(
        "UPDATE sessions SET new_component_id = $1 WHERE component_id = $2",
        [binary_uuid, old_id]
      )
    end)

    flush()

    # Drop old columns
    alter table(:components) do
      remove :id
      remove :parent_component_id
    end

    alter table(:dependencies) do
      remove :source_component_id
      remove :target_component_id
    end

    alter table(:similar_components) do
      remove :component_id
      remove :similar_component_id
    end

    alter table(:stories) do
      remove :component_id
    end

    alter table(:requirements) do
      remove :component_id
    end

    alter table(:sessions) do
      remove :component_id
    end

    # Rename new columns to original names
    rename table(:components), :new_id, to: :id
    rename table(:components), :new_parent_component_id, to: :parent_component_id
    rename table(:dependencies), :new_source_component_id, to: :source_component_id
    rename table(:dependencies), :new_target_component_id, to: :target_component_id
    rename table(:similar_components), :new_component_id, to: :component_id
    rename table(:similar_components), :new_similar_component_id, to: :similar_component_id
    rename table(:stories), :new_component_id, to: :component_id
    rename table(:requirements), :new_component_id, to: :component_id
    rename table(:sessions), :new_component_id, to: :component_id

    # Set components.id as primary key
    execute "ALTER TABLE components ADD PRIMARY KEY (id)"

    # Make requirements.component_id NOT NULL again
    execute "ALTER TABLE requirements ALTER COLUMN component_id SET NOT NULL"

    # Make dependencies columns NOT NULL again
    execute "ALTER TABLE dependencies ALTER COLUMN source_component_id SET NOT NULL"
    execute "ALTER TABLE dependencies ALTER COLUMN target_component_id SET NOT NULL"

    # Make similar_components columns NOT NULL again
    execute "ALTER TABLE similar_components ALTER COLUMN component_id SET NOT NULL"
    execute "ALTER TABLE similar_components ALTER COLUMN similar_component_id SET NOT NULL"

    # Recreate foreign key constraints
    alter table(:components) do
      modify :parent_component_id, references(:components, type: :uuid, on_delete: :nilify_all)
    end

    alter table(:dependencies) do
      modify :source_component_id, references(:components, type: :uuid, on_delete: :delete_all)
      modify :target_component_id, references(:components, type: :uuid, on_delete: :delete_all)
    end

    alter table(:similar_components) do
      modify :component_id, references(:components, type: :uuid, on_delete: :delete_all)
      modify :similar_component_id, references(:components, type: :uuid, on_delete: :delete_all)
    end

    alter table(:stories) do
      modify :component_id, references(:components, type: :uuid, on_delete: :nilify_all)
    end

    alter table(:requirements) do
      modify :component_id, references(:components, type: :uuid, on_delete: :delete_all)
    end

    alter table(:sessions) do
      modify :component_id, references(:components, type: :uuid, on_delete: :nothing)
    end

    # Recreate indexes
    create index(:components, [:parent_component_id])
    create index(:dependencies, [:source_component_id])
    create index(:dependencies, [:target_component_id])
    create unique_index(:dependencies, [:source_component_id, :target_component_id])
    create index(:similar_components, [:component_id])
    create index(:similar_components, [:similar_component_id])
    create unique_index(:similar_components, [:component_id, :similar_component_id])
    create index(:stories, [:component_id])
    create index(:requirements, [:component_id])
    create unique_index(:requirements, [:component_id, :name])
    create index(:sessions, [:component_id])
  end

  def down do
    raise "This migration cannot be safely reversed. UUID to integer conversion would lose data."
  end
end
