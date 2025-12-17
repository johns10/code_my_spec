defmodule CodeMySpec.Repo.Migrations.AllowNullComponentType do
  use Ecto.Migration

  def change do
    alter table(:components) do
      modify :type, :string, null: true
    end
  end
end
