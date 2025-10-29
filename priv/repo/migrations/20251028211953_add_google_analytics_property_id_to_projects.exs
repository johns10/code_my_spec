defmodule CodeMySpec.Repo.Migrations.AddGoogleAnalyticsPropertyIdToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :google_analytics_property_id, :string
    end
  end
end
