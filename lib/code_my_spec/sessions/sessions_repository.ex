defmodule CodeMySpec.Sessions.SessionsRepository do
  import Ecto.Query, warn: false
  alias CodeMySpec.Repo

  alias CodeMySpec.Sessions.{Session, Interaction}
  alias CodeMySpec.Users.Scope

  # Query for interactions ordered by inserted_at descending (most recent first)
  defp interactions_query do
    from i in Interaction, order_by: [desc: i.inserted_at]
  end

  @doc """
  Gets a single session.

  Raises `Ecto.NoResultsError` if the Session does not exist.

  ## Examples

      iex> get_session!(123)
      %Session{}

      iex> get_session!(456)
      ** (Ecto.NoResultsError)

  """
  def get_session!(%Scope{} = scope, id) do
    Session
    |> preload([
      :project,
      :component,
      [interactions: ^interactions_query()],
      [component: :parent_component],
      [child_sessions: [component: :project]]
    ])
    |> Repo.get_by!(id: id, user_id: scope.user.id)
    |> populate_display_name()
  end

  def get_session(%Scope{} = scope, id) do
    Session
    |> preload([
      :project,
      :component,
      [interactions: ^interactions_query()],
      [component: :parent_component],
      [child_sessions: [component: :project]]
    ])
    |> Repo.get_by(id: id, project_id: scope.active_project_id, user_id: scope.user.id)
    |> case do
      nil -> nil
      session -> populate_display_name(session)
    end
  end

  def preload_session(%Scope{} = _scope, %Session{} = session),
    do:
      Repo.preload(session, [
        :project,
        :component,
        [interactions: interactions_query()],
        [component: :parent_component],
        [child_sessions: [component: :project]]
      ])

  def complete_session(%Scope{} = scope, %Session{} = session) do
    true = session.account_id == scope.active_account_id
    true = session.user_id == scope.user.id

    with {:ok, session = %Session{}} <-
           session
           |> Session.changeset(%{status: :complete}, scope)
           |> Repo.update() do
      {:ok, session}
    end
  end

  def update_external_conversation_id(%Scope{} = scope, session_id, external_conversation_id) do
    case get_session(scope, session_id) do
      nil ->
        {:error, :session_not_found}

      session ->
        session
        |> Session.changeset(%{external_conversation_id: external_conversation_id}, scope)
        |> Repo.update()
    end
  end

  def populate_display_name(%Session{} = session) do
    %{session | display_name: Session.format_display_name(session)}
  end

  def populate_display_names(sessions) do
    Enum.map(sessions, &populate_display_name/1)
  end
end
