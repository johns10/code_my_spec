defmodule CodeMySpec.Repo.Migrations.CreateDependencies do
  use Ecto.Migration

  def change do
    create table(:dependencies) do
      add :type, :string, null: false
      add :source_component_id, references(:components, on_delete: :delete_all), null: false
      add :target_component_id, references(:components, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:dependencies, [:source_component_id, :target_component_id, :type])
    create index(:dependencies, [:source_component_id])
    create index(:dependencies, [:target_component_id])
    create index(:dependencies, [:type])
  end
end
