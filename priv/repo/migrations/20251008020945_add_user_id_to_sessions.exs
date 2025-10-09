defmodule CodeMySpec.Repo.Migrations.AddUserIdToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :user_id, references(:users, on_delete: :delete_all)
    end

    execute "UPDATE sessions SET user_id = 1 WHERE user_id IS NULL", ""

    alter table(:sessions) do
      modify :user_id, :bigint, null: false
    end

    create index(:sessions, [:user_id])
  end
end
