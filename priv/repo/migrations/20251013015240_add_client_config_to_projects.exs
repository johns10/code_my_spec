defmodule CodeMySpec.Repo.Migrations.AddClientConfigToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :client_api_url, :string
      add :deploy_key, :string
    end
  end
end
