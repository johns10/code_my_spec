defmodule CodeMySpec.Sessions.SessionsRepository do
  import Ecto.Query, warn: false
  alias CodeMySpec.Repo

  alias CodeMySpec.Sessions.Session
  alias CodeMySpec.Users.Scope
  alias CodeMySpec.Sessions.Interaction

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
      [component: :parent_component],
      [child_sessions: [component: :project]]
    ])
    |> Repo.get_by!(id: id, account_id: scope.active_account_id, user_id: scope.user.id)
    |> populate_display_name()
  end

  def get_session(%Scope{} = scope, id) do
    Session
    |> preload([
      :project,
      :component,
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
        [component: :parent_component],
        [child_sessions: [component: :project]]
      ])

  def complete_session_interaction(
        %Scope{} = scope,
        %Session{} = session,
        session_attrs,
        interaction_id,
        result
      ) do
    true = session.account_id == scope.active_account_id
    true = session.user_id == scope.user.id

    with {:ok, session = %Session{}} <-
           session
           |> Session.complete_interaction_changeset(session_attrs, interaction_id, result)
           |> Repo.update() do
      {:ok, session}
    end
  end

  def add_interaction(%Scope{} = scope, %Session{} = session, interaction_attrs) do
    true = session.account_id == scope.active_account_id
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

  def remove_interaction(%Scope{} = scope, %Session{} = session, interaction_id) do
    true = session.account_id == scope.active_account_id
    true = session.user_id == scope.user.id

    updated_interactions =
      Enum.reject(session.interactions, fn interaction ->
        interaction.id == interaction_id
      end)

    with {:ok, session = %Session{}} <-
           session
           |> Ecto.Changeset.change()
           |> Ecto.Changeset.put_embed(:interactions, updated_interactions)
           |> Repo.update() do
      # Refetch to get interactions in descending order
      session = get_session(scope, session.id)
      {:ok, session}
    end
  end

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

  def update_execution_mode(%Scope{} = scope, session_id, mode) when is_binary(mode) do
    with %Session{} = session <- get_session(scope, session_id),
         {:ok, updated_session} <- update_mode_and_regenerate_command(scope, session, mode) do
      {:ok, updated_session}
    else
      nil -> {:error, :session_not_found}
      error -> error
    end
  end

  defp update_mode_and_regenerate_command(scope, session, mode) do
    # Update the session's execution_mode
    changeset = Session.changeset(session, %{execution_mode: mode}, scope)

    with {:ok, updated_session} <- Repo.update(changeset) do
      # Check if there's a pending interaction and regenerate its command
      case Session.get_pending_interactions(updated_session) do
        [pending | _] ->
          regenerate_pending_command(scope, updated_session, pending)

        [] ->
          {:ok, updated_session}
      end
    end
  end

  defp regenerate_pending_command(scope, session, pending_interaction) do
    session_module = session.type
    opts = build_opts_from_execution_mode(session.execution_mode)

    with {:ok, step_module} <- session_module.get_next_interaction(session),
         {:ok, new_command} <- step_module.get_command(scope, session, opts),
         {:ok, session} <- remove_interaction(scope, session, pending_interaction.id),
         interaction <- Interaction.new_with_command(new_command),
         {:ok, updated_session} <- add_interaction(scope, session, interaction) do
      {:ok, updated_session}
    end
  end

  defp build_opts_from_execution_mode(:auto), do: [auto: true]
  defp build_opts_from_execution_mode(:manual), do: []
  defp build_opts_from_execution_mode(:agentic), do: [agentic: true]

  def populate_display_name(%Session{} = session) do
    %{session | display_name: Session.format_display_name(session)}
  end

  def populate_display_names(sessions) do
    Enum.map(sessions, &populate_display_name/1)
  end
end
