defmodule CodeMySpec.Repo.Migrations.AddExecutionModeToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :execution_mode, :string, default: "manual"
    end

    # Set existing sessions to manual mode
    execute "UPDATE sessions SET execution_mode = 'manual' WHERE execution_mode IS NULL"
  end
end
