defmodule CodeMySpec.ContextDesignReviewSessions.Steps.Finalize do
  @moduledoc """
  Completes the context review session by staging the review file with git
  and marking the session as complete.

  This step takes the review summary document generated during ExecuteReview
  and stages it for commit using git add.
  """

  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.{Session, Steps.Helpers}
  alias CodeMySpec.Utils

  @impl true
  def get_command(_scope, %Session{} = session, _opts) do
    with {:ok, component} <- extract_component(session),
         {:ok, project} <- extract_project(session),
         {:ok, review_file_path} <- calculate_review_file_path(component, project),
         {:ok, relative_path} <- strip_docs_prefix(review_file_path),
         {:ok, git_command} <- build_git_command(relative_path) do
      Helpers.build_shell_command(__MODULE__, git_command)
    end
  end

  @impl true
  def handle_result(_scope, session, result, _opts) do
    case result.status do
      :ok ->
        session_updates = build_session_updates(:complete, session)
        {:ok, session_updates, result}

      :error ->
        session_updates = build_session_updates(:failed, session)
        {:ok, session_updates, result}

      _other ->
        session_updates = build_session_updates(:failed, session)
        {:ok, session_updates, result}
    end
  end

  # Private Functions

  defp extract_component(%Session{component: nil}),
    do: {:error, "Context component not found in session"}

  defp extract_component(%Session{component: component}), do: {:ok, component}

  defp extract_project(%Session{project: nil}),
    do: {:error, "Project not found in session"}

  defp extract_project(%Session{project: project}), do: {:ok, project}

  defp calculate_review_file_path(component, project) do
    %{design_file: context_design_path} = Utils.component_files(component, project)

    # Context design path: "docs/design/code_my_spec/sessions.md"
    # Review file path: "docs/design/code_my_spec/sessions/design_review.md"
    review_path =
      context_design_path
      |> String.replace_suffix(".md", "/design_review.md")

    {:ok, review_path}
  end

  defp strip_docs_prefix("docs/" <> rest), do: {:ok, rest}

  defp strip_docs_prefix(path),
    do: {:error, "Invalid design file path: #{path}"}

  defp build_git_command(relative_path) do
    command = "git -C docs add #{relative_path}"
    {:ok, command}
  end

  defp build_session_updates(status, session) do
    finalized_at = DateTime.utc_now()

    updated_state =
      (session.state || %{})
      |> Map.put(:finalized_at, finalized_at)

    %{
      status: status,
      state: updated_state
    }
  end
end
