defmodule CodeMySpec.Repo.Migrations.AddExternalConversationIdToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :external_conversation_id, :string
    end

    create index(:sessions, [:external_conversation_id])
  end
end
