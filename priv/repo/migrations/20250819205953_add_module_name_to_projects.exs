defmodule CodeMySpec.Repo.Migrations.AddModuleNameToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :module_name, :string
    end
  end
end
