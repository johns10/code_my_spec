defmodule CodeMySpec.Repo.Migrations.RemoveContentRepoFromProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      remove :content_repo, :string
    end
  end
end
