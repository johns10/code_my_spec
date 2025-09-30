defmodule CodeMySpec.Repo.Migrations.CreateComponents do
  use Ecto.Migration

  def change do
    create table(:components) do
      add :name, :string, null: false
      add :type, :string, null: false
      add :module_name, :string, null: false
      add :description, :text
      add :project_id, references(:projects, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:components, [:module_name, :project_id])
    create index(:components, [:project_id])
    create index(:components, [:type])
  end
end
