defmodule CodeMySpec.ContextComponentsDesignSessions.Steps.SpawnReviewSession do
  @moduledoc """
  Creates a single ComponentDesignReviewSession in agentic mode that analyzes all generated
  component designs within the context for consistency, missing dependencies, and integration issues.

  Returns a spawn_sessions command with review_session_id in metadata for the client to start.

  The review session's orchestrator handles determining which designs to review and where to write output.
  """

  @behaviour CodeMySpec.Sessions.StepBehaviour

  require Logger

  alias CodeMySpec.Sessions
  alias CodeMySpec.Sessions.{Command, Session}
  alias CodeMySpec.Users.Scope

  @impl true
  def get_command(%Scope{} = scope, %Session{} = session, _opts) do
    with {:ok, _context_component} <- get_context_component(session),
         {:ok, parent_session} <- get_parent_session(scope, session),
         {:ok, review_session} <- get_or_create_review_session(scope, parent_session) do
      command =
        Command.new(__MODULE__, "spawn_sessions",
          metadata: %{
            child_session_ids: [review_session.id],
            session_type: :component_design_review,
            execution_strategy: :async
          }
        )

      {:ok, command}
    end
  end

  @impl true
  def handle_result(%Scope{} = scope, %Session{} = session, result, _opts) do
    with {:ok, review_session_id} <- extract_review_session_id_from_session(session),
         {:ok, review_session} <- get_review_session(scope, review_session_id),
         :ok <- validate_review_session_status(review_session) do
      {:ok, %{}, %{result | status: :ok}}
    else
      # "Not found" errors are returned directly
      {:error, "Missing" <> _} = error ->
        error

      {:error, "Review session not found"} = error ->
        error

      {:error, "Command not found"} = error ->
        error

      # Validation errors are wrapped in result
      {:error, validation_error} ->
        {:ok, %{}, %{result | status: :error, error_message: validation_error}}
    end
  end

  # Private Functions - get_command helpers

  defp get_parent_session(%Scope{} = scope, %Session{id: id}) do
    case Sessions.SessionsRepository.get_session(scope, id) do
      nil -> {:error, "Session not found"}
      session -> {:ok, session}
    end
  end

  defp get_context_component(%Session{component: nil}) do
    {:error, "Context component not found"}
  end

  defp get_context_component(%Session{component: component}) do
    {:ok, component}
  end

  defp get_or_create_review_session(
         %Scope{} = scope,
         %Session{child_sessions: child_sessions} = parent_session
       ) do
    # Check if a review session already exists
    case find_review_session(child_sessions) do
      {:ok, review_session} ->
        {:ok, review_session}

      :not_found ->
        create_review_session(scope, parent_session)
    end
  end

  defp find_review_session(child_sessions) do
    case Enum.find(child_sessions, fn session ->
           session.type == CodeMySpec.ComponentDesignReviewSessions
         end) do
      nil -> :not_found
      session -> {:ok, session}
    end
  end

  defp create_review_session(%Scope{} = scope, %Session{} = parent_session) do
    attrs = %{
      type: CodeMySpec.ComponentDesignReviewSessions,
      component_id: parent_session.component_id,
      session_id: parent_session.id,
      execution_mode: :agentic,
      agent: parent_session.agent,
      environment: parent_session.environment,
      project_id: scope.active_project_id
    }

    case Sessions.create_session(scope, attrs) do
      {:ok, session} ->
        {:ok, session}

      {:error, changeset} ->
        Logger.error("Failed to create review session: #{inspect(changeset)}")
        {:error, "Failed to create review session"}
    end
  end

  # Private Functions - handle_result helpers

  defp extract_review_session_id_from_session(%Session{
         interactions: [%{command: command, result: nil} | _]
       }) do
    extract_review_session_id(command)
  end

  defp extract_review_session_id_from_session(%Session{}) do
    {:error, "Command not found"}
  end

  defp extract_review_session_id(%Command{metadata: metadata}) when is_map(metadata) do
    # Handle both atom and string keys from database
    child_session_ids = metadata[:child_session_ids] || metadata["child_session_ids"]

    case child_session_ids do
      [id | _] when is_integer(id) -> {:ok, id}
      _ -> {:error, "Missing child_session_ids in command metadata"}
    end
  end

  defp extract_review_session_id(%Command{}) do
    {:error, "Missing child_session_ids in command metadata"}
  end

  defp get_review_session(%Scope{} = scope, review_session_id) do
    case Sessions.get_session(scope, review_session_id) do
      nil -> {:error, "Review session not found"}
      session -> {:ok, session}
    end
  end

  defp validate_review_session_status(%Session{status: :complete}) do
    :ok
  end

  defp validate_review_session_status(%Session{status: :active}) do
    {:error, "Review session still running"}
  end

  defp validate_review_session_status(%Session{status: :failed}) do
    {:error, "Review session failed"}
  end

  defp validate_review_session_status(%Session{status: :cancelled}) do
    {:error, "Review session cancelled"}
  end
end
