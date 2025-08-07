defmodule CodeMySpec.Sessions.Session do
  alias Decimal.Context
  alias CodeMySpec.Projects.Project
  alias CodeMySpec.Accounts.Account
  alias CodeMySpec.Sessions.Interaction
  use Ecto.Schema
  import Ecto.Changeset

  schema "sessions" do
    field :type, Ecto.Enum, values: [:context_design]
    field :agent, Ecto.Enum, values: [:claude_code]
    field :environment, Ecto.Enum, values: [:local, :vscode]
    field :status, Ecto.Enum, values: [:active, :complete, :failed]

    field :state, :map

    belongs_to :project, Project
    belongs_to :account, Account
    belongs_to :context, Context

    embeds_many :interactions, Interaction

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(session, attrs, user_scope) do
    session
    |> cast(attrs, [:type, :agent, :environment, :status, :state])
    |> validate_required([:type, :status])
    |> cast_embed(:interactions)
    |> put_change(:account_id, user_scope.active_account.id)
    |> put_change(:project_id, user_scope.active_project.id)
  end

  def add_interaction(session, command) do
    interaction = Interaction.new_with_command(command)
    %{session | interactions: [interaction | session.interactions]}
  end

  def complete_interaction(session, interaction_id, result) do
    interactions =
      Enum.map(session.interactions, fn interaction ->
        if interaction.id == interaction_id do
          Interaction.complete_with_result(interaction, result)
        else
          interaction
        end
      end)

    %{session | interactions: interactions}
  end

  def get_pending_interactions(session) do
    Enum.filter(session.interactions, &Interaction.pending?/1)
  end

  def get_completed_interactions(session) do
    Enum.filter(session.interactions, &Interaction.completed?/1)
  end
end
