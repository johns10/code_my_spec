defmodule CodeMySpec.Sessions.SessionsRepository do
  import Ecto.Query, warn: false
  alias CodeMySpec.Repo

  alias CodeMySpec.Sessions.Session
  alias CodeMySpec.Users.Scope

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
    |> preload([:project, :component, [component: :parent_component]])
    |> Repo.get_by!(id: id, account_id: scope.active_account.id, user_id: scope.user.id)
  end

  def get_session(%Scope{} = scope, id) do
    Session
    |> preload([:project, :component, [component: :parent_component]])
    |> Repo.get_by(id: id, account_id: scope.active_account.id, user_id: scope.user.id)
  end

  @doc """
  Gets a single session with all child sessions preloaded.

  Returns nil if the Session does not exist.

  ## Examples

      iex> get_session_with_children(scope, 123)
      %Session{child_sessions: [%Session{}, ...]}

      iex> get_session_with_children(scope, 456)
      nil

  """
  def get_session_with_children(%Scope{} = scope, id) do
    Session
    |> preload([
      :project,
      :component,
      [component: :parent_component],
      [child_sessions: [component: :project]]
    ])
    |> Repo.get_by(id: id, account_id: scope.active_account.id, user_id: scope.user.id)
  end

  def complete_session_interaction(
        %Scope{} = scope,
        %Session{} = session,
        session_attrs,
        interaction_id,
        result
      ) do
    true = session.account_id == scope.active_account.id
    true = session.user_id == scope.user.id

    with {:ok, session = %Session{}} <-
           session
           |> Session.complete_interaction_changeset(session_attrs, interaction_id, result)
           |> Repo.update() do
      {:ok, session}
    end
  end

  def add_interaction(%Scope{} = scope, %Session{} = session, interaction_attrs) do
    true = session.account_id == scope.active_account.id
    true = session.user_id == scope.user.id

    with {:ok, session = %Session{}} <-
           session
           |> Session.add_interaction_changeset(interaction_attrs)
           |> Repo.update() do
      # Refetch to get interactions in descending order
      session = get_session(scope, session.id)
      {:ok, session}
    end
  end

  def complete_session(%Scope{} = scope, %Session{} = session) do
    true = session.account_id == scope.active_account.id
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
end
