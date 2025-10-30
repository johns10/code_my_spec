defmodule CodeMySpec.Sessions.Session do
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Projects.Project
  alias CodeMySpec.Accounts.Account
  alias CodeMySpec.Users.User
  alias CodeMySpec.Sessions.Interaction
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          type:
            CodeMySpec.ContextDesignSessions
            | CodeMySpec.ComponentDesignSessions
            | CodeMySpec.ComponentDesignReviewSessions
            | CodeMySpec.ComponentTestSessions
            | CodeMySpec.ComponentCodingSessions
            | CodeMySpec.IntegrationSessions
            | nil,
          agent: :claude_code | nil,
          environment: :local | :vscode | nil,
          execution_mode: :manual | :auto | :agentic | nil,
          status: :active | :complete | :failed | :cancelled | nil,
          state: map() | nil,
          project_id: integer() | nil,
          project: Project.t() | Ecto.Association.NotLoaded.t() | nil,
          account_id: integer() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t() | nil,
          user_id: integer() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t() | nil,
          component_id: integer() | nil,
          component: Component.t() | Ecto.Association.NotLoaded.t() | nil,
          session_id: integer() | nil,
          parent_session: t() | Ecto.Association.NotLoaded.t() | nil,
          child_sessions: [t()] | Ecto.Association.NotLoaded.t(),
          external_conversation_id: String.t() | nil,
          interactions: [Interaction.t()],
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "sessions" do
    field :type, CodeMySpec.Sessions.SessionType
    field :agent, Ecto.Enum, values: [:claude_code]
    field :environment, Ecto.Enum, values: [:local, :vscode]
    field :execution_mode, Ecto.Enum, values: [:manual, :auto, :agentic], default: :manual
    field :status, Ecto.Enum, values: [:active, :complete, :failed, :cancelled], default: :active
    field :external_conversation_id, :string

    field :state, :map

    belongs_to :project, Project
    belongs_to :account, Account
    belongs_to :user, User
    belongs_to :component, Component
    belongs_to :parent_session, __MODULE__, foreign_key: :session_id

    has_many :child_sessions, __MODULE__, foreign_key: :session_id

    embeds_many :interactions, Interaction

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(session, attrs, user_scope) do
    session
    |> cast(attrs, [
      :type,
      :agent,
      :environment,
      :execution_mode,
      :status,
      :state,
      :component_id,
      :session_id,
      :external_conversation_id
    ])
    |> validate_required([:type])
    |> cast_embed(:interactions)
    |> put_change(:account_id, user_scope.active_account.id)
    |> put_change(:project_id, user_scope.active_project.id)
    |> put_change(:user_id, user_scope.user.id)
  end

  def complete_interaction_changeset(session, session_attrs, interaction_id, result) do
    result_attrs = Map.from_struct(result)

    interactions =
      Enum.map(session.interactions, fn
        %{id: ^interaction_id} = interaction ->
          Interaction.changeset(interaction, %{result: result_attrs})

        interaction ->
          interaction
      end)

    session
    |> cast(session_attrs, [
      :type,
      :agent,
      :environment,
      :execution_mode,
      :status,
      :state,
      :component_id,
      :session_id,
      :external_conversation_id
    ])
    |> put_embed(:interactions, interactions)
  end

  def get_pending_interactions(session) do
    Enum.filter(session.interactions, &Interaction.pending?/1)
  end

  def get_completed_interactions(session) do
    Enum.filter(session.interactions, &Interaction.completed?/1)
  end

  def add_interaction_changeset(session, %Interaction{} = interaction) do
    change(session)
    |> put_embed(:interactions, [interaction | session.interactions])
  end
end
