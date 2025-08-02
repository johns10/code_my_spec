defmodule CodeMySpec.Repo.Migrations.RemoveTypeFromDependencies do
  use Ecto.Migration

  def change do
    drop unique_index(:dependencies, [:source_component_id, :target_component_id, :type])
    drop index(:dependencies, [:type])

    # Remove duplicate dependencies (keep one per source/target pair)
    execute """
    DELETE FROM dependencies
    WHERE id NOT IN (
      SELECT MIN(id)
      FROM dependencies
      GROUP BY source_component_id, target_component_id
    )
    """

    alter table(:dependencies) do
      remove :type, :string
    end

    create unique_index(:dependencies, [:source_component_id, :target_component_id])
  end
end
