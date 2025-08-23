defmodule CodeMySpec.Repo.Migrations.AddComponentStatusToComponents do
  use Ecto.Migration

  def change do
    alter table(:components) do
      add :component_status, :map
    end
  end
end