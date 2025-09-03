defmodule CodeMySpec.Repo.Migrations.AddAccountIdToComponents do
  use Ecto.Migration

  def change do
    alter table(:components) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false, default: 4
    end

    create index(:components, [:account_id])
    create unique_index(:components, [:name, :account_id])
    create unique_index(:components, [:module_name, :account_id])
  end
end
