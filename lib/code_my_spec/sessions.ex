defmodule CodeMySpec.Sessions do
  @moduledoc """
  The Sessions context.
  """

  import Ecto.Query, warn: false
  alias CodeMySpec.Sessions.Result
  alias CodeMySpec.Sessions.SessionsRepository
  alias CodeMySpec.Sessions.InteractionsRepository
  alias CodeMySpec.Repo

  alias CodeMySpec.Sessions.{
    Session,
    ResultHandler,
    CommandResolver,
    SessionsBroadcaster,
    Interaction,
    SessionServer
  }

  alias CodeMySpec.Users.Scope

  @doc """
  Subscribes to scoped notifications about any session changes.

  The broadcasted messages match the pattern:

    * {:created, %Session{}}
    * {:updated, %Session{}}
    * {:deleted, %Session{}}

  """
  def subscribe_sessions(%Scope{} = scope) do
    key = scope.active_account_id

    Phoenix.PubSub.subscribe(CodeMySpec.PubSub, "account:#{key}:sessions")
  end

  @doc """
  Subscribes to user-level notifications about session changes.

  Accepts either a %Scope{} or a user_id integer.

  The broadcasted messages match the pattern:

    * {:created, %Session{}}
    * {:updated, %Session{}}
    * {:deleted, %Session{}}

  """
  def subscribe_user_sessions(%Scope{} = scope) do
    user_id = scope.user.id

    Phoenix.PubSub.subscribe(CodeMySpec.PubSub, "user:#{user_id}:sessions")
  end

  def subscribe_user_sessions(user_id) when is_integer(user_id) do
    Phoenix.PubSub.subscribe(CodeMySpec.PubSub, "user:#{user_id}:sessions")
  end

  @doc """
  Returns the list of sessions.

  ## Examples

      iex> list_sessions(scope)
      [%Session{}, ...]

      iex> list_sessions(scope, status: [:active])
      [%Session{}, ...]

      iex> list_sessions(scope, status: [:active, :complete])
      [%Session{}, ...]

  """
  def list_sessions(%Scope{} = scope, opts \\ []) do
    status_filter = Keyword.get(opts, :status, [:active])

    Session
    |> where([s], s.project_id == ^scope.active_project_id)
    |> where([s], s.user_id == ^scope.user.id)
    |> where([s], s.status in ^status_filter)
    |> preload([:project, :component, :interactions])
    |> Repo.all()
    |> SessionsRepository.populate_display_names()
  end

  defdelegate get_session!(scope, id), to: SessionsRepository
  defdelegate get_session(scope, id), to: SessionsRepository

  defdelegate update_external_conversation_id(scope, session_id, external_conversation_id),
    to: SessionsRepository

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
      SessionsBroadcaster.broadcast_created(scope, session)
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
    true = session.account_id == scope.active_account_id
    true = session.user_id == scope.user.id

    with {:ok, session = %Session{}} <-
           session
           |> Session.changeset(attrs, scope)
           |> Repo.update() do
      SessionsBroadcaster.broadcast_updated(scope, session)
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
    true = session.account_id == scope.active_account_id
    true = session.user_id == scope.user.id

    with {:ok, session = %Session{}} <-
           Repo.delete(session) do
      SessionsBroadcaster.broadcast_deleted(scope, session)
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
    true = session.account_id == scope.active_account_id
    true = session.user_id == scope.user.id

    Session.changeset(session, attrs, scope)
  end

  def handle_result(%Scope{} = scope, session_id, interaction_id, result, opts \\ []) do
    with {:ok, %Session{} = session} <-
           ResultHandler.handle_result(scope, session_id, interaction_id, result, opts) do
      SessionsBroadcaster.broadcast_updated(scope, session)
      {:ok, session}
    end
  end

  def next_command(%Scope{} = scope, session_id, opts \\ []) do
    with {:ok, %Session{} = session} <-
           CommandResolver.next_command(scope, session_id, opts) do
      SessionsBroadcaster.broadcast_updated(scope, session)
      {:ok, session}
    end
  end

  @doc """
  Executes a session step synchronously using SessionServer.

  Starts a SessionServer if one doesn't exist for this session.
  Blocks until the step completes or fails.

  Note: SessionServer handles broadcasting, so this function doesn't broadcast.
  """
  def execute(%Scope{} = scope, session_id, opts \\ []) do
    with {:ok, server} <- get_or_start_session_server(session_id) do
      GenServer.call(server, {:run, scope, opts}, :infinity)
    end
  end

  @doc """
  Runs a session step asynchronously using SessionServer.

  Creates the interaction synchronously, then spawns a task for execution.
  Returns interaction info immediately so caller can track progress.

  ## Returns
  - `{:ok, %{interaction_id: id, command_module: module, task_pid: pid}}` - Interaction created, execution started
  - `{:error, reason}` - Failed to create interaction or start server

  ## Sandbox Access
  In tests, you can use the task_pid to grant sandbox access:
  ```
  {:ok, %{task_pid: pid}} = Sessions.run(scope, session_id)
  Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
  ```
  """
  def run(%Scope{} = scope, session_id, opts \\ []) do
    with {:ok, server} <- get_or_start_session_server(session_id) do
      GenServer.call(server, {:run, scope, opts}, :infinity)
    end
  end

  @doc """
  Delivers an external result to a waiting SessionServer.

  Used for truly async operations like Claude sessions where results
  come back through callbacks/webhooks.

  ## Parameters
  - `session_id` - Session ID
  - `interaction_id` - Interaction ID
  - `result` - Result map
  - `opts` - Optional keyword list (e.g., cwd for file operations)
  """
  def deliver_result_to_server(session_id, interaction_id, result, opts \\ []) do
    require Logger
    Logger.info("Sessions.deliver_result_to_server: session_id=#{session_id}, interaction_id=#{interaction_id}")

    case get_session_server(session_id) do
      {:ok, server} ->
        Logger.info("Sessions.deliver_result_to_server: Found server #{inspect(server)}, casting message")
        GenServer.cast(server, {:deliver_result, interaction_id, result, opts})
        :ok

      {:error, :not_found} ->
        Logger.error("Sessions.deliver_result_to_server: SessionServer not found for session #{session_id}")
        {:error, :session_server_not_found}
    end
  end

  # Private helpers for SessionServer management

  defp get_or_start_session_server(session_id) do
    case get_session_server(session_id) do
      {:ok, pid} -> {:ok, pid}
      {:error, :not_found} -> SessionServer.start(session_id)
    end
  end

  defp get_session_server(session_id) do
    case Registry.lookup(CodeMySpec.Sessions.SessionRegistry, session_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
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

  @doc """
  Updates a session's execution mode and regenerates pending command if needed.

  If the session has a pending interaction (command without result), the command
  will be regenerated with the new execution mode settings.
  """
  def update_execution_mode(%Scope{} = scope, session_id, mode) when is_binary(mode) do
    with {:ok, session} <- get_session_tuple(scope, session_id),
         {:ok, updated_session} <- update_session(scope, session, %{execution_mode: mode}),
         {:ok, pending} <- get_pending_interaction(updated_session),
         session_module <- updated_session.type,
         opts <- build_opts_from_execution_mode(updated_session.execution_mode),
         {:ok, step_module} <- session_module.get_next_interaction(updated_session),
         {:ok, new_command} <- step_module.get_command(scope, updated_session, opts),
         {:ok, _deleted} <- InteractionsRepository.delete(pending),
         new_interaction <- Interaction.new_with_command(new_command),
         {:ok, _created} <- InteractionsRepository.create(updated_session.id, new_interaction),
         final_session <- SessionsRepository.get_session(scope, session_id) do
      SessionsBroadcaster.broadcast_updated(scope, final_session)
      SessionsBroadcaster.broadcast_mode_change(scope, session_id, final_session.execution_mode)
      {:ok, final_session}
    else
      :no_pending ->
        # No pending interaction, just broadcast the mode change
        session = SessionsRepository.get_session(scope, session_id)
        SessionsBroadcaster.broadcast_updated(scope, session)
        SessionsBroadcaster.broadcast_mode_change(scope, session_id, session.execution_mode)
        {:ok, session}

      error ->
        error
    end
  end

  defp get_pending_interaction(%Session{} = session) do
    case Session.get_pending_interactions(session) do
      [pending | _] -> {:ok, pending}
      [] -> :no_pending
    end
  end

  defp get_session_tuple(scope, session_id) do
    case SessionsRepository.get_session(scope, session_id) do
      %Session{} = session -> {:ok, session}
      nil -> {:error, :session_not_found}
    end
  end

  defp build_opts_from_execution_mode(:auto), do: [auto: true]
  defp build_opts_from_execution_mode(:manual), do: []
  defp build_opts_from_execution_mode(:agentic), do: [agentic: true]
end
