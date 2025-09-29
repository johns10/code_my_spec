defmodule CodeMySpec.Sessions do
  @moduledoc """
  The Sessions context.
  """

  import Ecto.Query, warn: false
  alias CodeMySpec.Sessions.Result
  alias CodeMySpec.Sessions.SessionsRepository
  alias CodeMySpec.Repo

  alias CodeMySpec.Sessions.{Session, Interaction, ResultHandler, Orchestrator}
  alias CodeMySpec.Users.Scope

  @doc """
  Subscribes to scoped notifications about any session changes.

  The broadcasted messages match the pattern:

    * {:created, %Session{}}
    * {:updated, %Session{}}
    * {:deleted, %Session{}}

  """
  def subscribe_sessions(%Scope{} = scope) do
    key = scope.active_account.id

    Phoenix.PubSub.subscribe(CodeMySpec.PubSub, "account:#{key}:sessions")
  end

  defp broadcast(%Scope{} = scope, message) do
    key = scope.active_account.id

    Phoenix.PubSub.broadcast(CodeMySpec.PubSub, "account:#{key}:sessions", message)
  end

  @doc """
  Returns the list of sessions.

  ## Examples

      iex> list_sessions(scope)
      [%Session{}, ...]

  """
  def list_sessions(%Scope{} = scope) do
    Repo.all_by(Session, account_id: scope.active_account.id)
  end

  defdelegate get_session!(scope, id), to: SessionsRepository
  defdelegate get_session(scope, id), to: SessionsRepository

  @doc """
  Creates a session.

  ## Examples

      iex> create_session(%{field: value})
      {:ok, %Session{}}

      iex> create_session(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_session(%Scope{} = scope, attrs) do
    with {:ok, session = %Session{}} <-
           %Session{}
           |> Session.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast(scope, {:created, session})
      {:ok, session}
    end
  end

  @doc """
  Updates a session.

  ## Examples

      iex> update_session(session, %{field: new_value})
      {:ok, %Session{}}

      iex> update_session(session, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_session(%Scope{} = scope, %Session{} = session, attrs) do
    true = session.account_id == scope.active_account.id

    with {:ok, session = %Session{}} <-
           session
           |> Session.changeset(attrs, scope)
           |> Repo.update() do
      broadcast(scope, {:updated, session})
      {:ok, session}
    end
  end

  def complete_session_interaction(
        %Scope{} = scope,
        %Session{} = session,
        session_attrs,
        interaction_id,
        %Result{} = result
      ) do
    true = session.account_id == scope.active_account.id

    with {:ok, session = %Session{}} <-
           SessionsRepository.complete_session_interaction(
             scope,
             session,
             session_attrs,
             interaction_id,
             result
           ) do
      broadcast(scope, {:updated, session})
      {:ok, session}
    end
  end

  @doc """
  Deletes a session.

  ## Examples

      iex> delete_session(session)
      {:ok, %Session{}}

      iex> delete_session(session)
      {:error, %Ecto.Changeset{}}

  """
  def delete_session(%Scope{} = scope, %Session{} = session) do
    true = session.account_id == scope.active_account.id

    with {:ok, session = %Session{}} <-
           Repo.delete(session) do
      broadcast(scope, {:deleted, session})
      {:ok, session}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking session changes.

  ## Examples

      iex> change_session(session)
      %Ecto.Changeset{data: %Session{}}

  """
  def change_session(%Scope{} = scope, %Session{} = session, attrs \\ %{}) do
    true = session.account_id == scope.active_account.id

    Session.changeset(session, attrs, scope)
  end

  def handle_result(%Scope{} = scope, session_id, interaction_id, result) do
    with {:ok, %Session{} = session} <-
           ResultHandler.handle_result(scope, session_id, interaction_id, result) do
      broadcast(scope, {:updated, session})
      {:ok, session}
    end
  end

  def next_command(%Scope{} = scope, session_id) do
    with {:ok, %Interaction{} = interaction, %Session{} = session} <-
           Orchestrator.next_command(scope, session_id) do
      broadcast(scope, {:updated, session})
      {:ok, interaction}
    end
  end

  def create_result(%Scope{} = _scope, result_attrs) do
    result_attrs
    |> Result.changeset()
    |> Ecto.Changeset.apply_action(:insert)
  end

  def update_result(%Scope{} = _scope, %Result{} = result, result_attrs) do
    result
    |> Result.changeset(result_attrs)
    |> Ecto.Changeset.apply_action(:update)
  end
end
