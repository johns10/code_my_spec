defmodule CodeMySpec.Repo.Migrations.MovePriorityFromStoriesToComponents do
  use Ecto.Migration

  def change do
    alter table(:components) do
      add :priority, :integer
    end

    alter table(:stories) do
      remove :priority
    end
  end
end
