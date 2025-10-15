defmodule CodeMySpec.Repo.Migrations.DropComponentsNameAccountIdUniqueConstraint do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:components, [:name, :account_id], name: :components_name_account_id_index)
  end
end
