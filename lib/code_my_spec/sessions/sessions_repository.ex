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
    |> Repo.get_by!(id: id, account_id: scope.active_account.id)
  end

  def get_session(%Scope{} = scope, id) do
    Session
    |> preload([:project, :component, [component: :parent_component]])
    |> Repo.get_by(id: id, account_id: scope.active_account.id)
  end

  def complete_session_interaction(
        %Scope{} = scope,
        %Session{} = session,
        session_attrs,
        interaction_id,
        result
      ) do
    true = session.account_id == scope.active_account.id

    with {:ok, session = %Session{}} <-
           session
           |> Session.complete_interaction_changeset(session_attrs, interaction_id, result)
           |> Repo.update() do
      {:ok, session}
    end
  end

  def add_interaction(%Scope{} = scope, %Session{} = session, interaction_attrs) do
    true = session.account_id == scope.active_account.id

    with {:ok, session = %Session{}} <-
           session
           |> Session.add_interaction_changeset(interaction_attrs)
           |> Repo.update() do
      {:ok, session}
    end
  end
end
