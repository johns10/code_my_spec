defmodule CodeMySpec.Repo.Migrations.AddTitleToContents do
  use Ecto.Migration

  def change do
    alter table(:contents) do
      add :title, :string
    end
  end
end
