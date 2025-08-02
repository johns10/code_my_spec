defmodule CodeMySpec.Repo.Migrations.AddUniqueConstraintToStoriesTitleProjectId do
  use Ecto.Migration

  def change do
    create unique_index(:stories, [:title, :project_id])
  end
end
