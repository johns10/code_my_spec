defmodule CodeMySpec.Repo.Migrations.AddContentRepoToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :content_repo, :string
    end
  end
end
