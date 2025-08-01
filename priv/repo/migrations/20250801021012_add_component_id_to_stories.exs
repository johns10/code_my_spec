defmodule CodeMySpec.Repo.Migrations.AddComponentIdToStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add :component_id, references(:components, on_delete: :nilify_all)
    end

    create index(:stories, [:component_id])
  end
end
