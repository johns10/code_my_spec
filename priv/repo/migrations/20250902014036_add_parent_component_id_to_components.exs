defmodule CodeMySpec.Repo.Migrations.AddParentComponentIdToComponents do
  use Ecto.Migration

  def change do
    alter table(:components) do
      add :parent_component_id, references(:components, on_delete: :nilify_all), null: true
    end

    create index(:components, [:parent_component_id])
  end
end
