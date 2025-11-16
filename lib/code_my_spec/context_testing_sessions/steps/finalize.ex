defmodule CodeMySpec.ContextTestingSessions.Steps.Finalize do
  @moduledoc """
  Completes the context testing session by committing all test files from child
  ComponentTestingSession workflows, pushing the test branch to remote, and marking
  the session as complete.
  """

  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.ContextTestingSessions.Utils
  alias CodeMySpec.Sessions.{Command, Result}
  alias CodeMySpec.Users.Scope

  @impl true
  def get_command(%Scope{} = _scope, session, _opts) do
    with {:ok, context_component} <- get_context_component(session),
         {:ok, child_sessions} <- get_child_sessions(session),
         {:ok, test_files} <- collect_test_files(child_sessions),
         {:ok, branch_name} <- get_branch_name(session) do
      command_string =
        build_git_command(context_component, child_sessions, test_files, branch_name)

      metadata = %{
        branch_name: branch_name,
        committed_files: length(test_files)
      }

      command = Command.new(__MODULE__, command_string, metadata: metadata)
      {:ok, command}
    end
  end

  @impl true
  def handle_result(_scope, _session, %Result{status: :ok} = result, _opts) do
    session_updates = %{status: :complete}
    {:ok, session_updates, result}
  end

  def handle_result(
        _scope,
        session,
        %Result{status: :error, error_message: error_message} = result,
        _opts
      ) do
    updated_state =
      Map.merge(session.state || %{}, %{
        finalized_at: DateTime.utc_now(),
        error: error_message
      })

    session_updates = %{
      status: :failed,
      state: updated_state
    }

    {:ok, session_updates, result}
  end

  # Private Functions

  defp get_context_component(%{component_id: nil}),
    do: {:error, "Context component not found in session"}

  defp get_context_component(%{component: nil}),
    do: {:error, "Context component not found in session"}

  defp get_context_component(%{component: component}), do: {:ok, component}

  defp get_child_sessions(%{child_sessions: []}), do: {:error, "No child sessions found"}
  defp get_child_sessions(%{child_sessions: nil}), do: {:error, "No child sessions found"}
  defp get_child_sessions(%{child_sessions: children}), do: {:ok, children}

  defp get_branch_name(%{state: %{branch_name: branch_name}}) when is_binary(branch_name),
    do: {:ok, branch_name}

  defp get_branch_name(session) do
    # Fallback to generating branch name from session if not stored in state
    {:ok, Utils.branch_name(session)}
  end

  defp collect_test_files(child_sessions) do
    test_files =
      child_sessions
      |> Enum.map(fn child_session ->
        component = CodeMySpec.Repo.preload(child_session, component: :project).component
        project = component.project

        %{test_file: test_file} = CodeMySpec.Utils.component_files(component, project)
        test_file
      end)

    {:ok, test_files}
  end

  defp build_git_command(context_component, child_sessions, test_files, branch_name) do
    commit_message = build_commit_message(context_component, child_sessions)
    file_list = Enum.join(test_files, " ")

    """
    git add #{file_list} && git commit -m "$(cat <<'EOF'
    #{commit_message}
    EOF
    )" && git push -u origin #{branch_name}
    """
    |> String.trim()
  end

  defp build_commit_message(context_component, child_sessions) do
    title = "Generate tests for #{context_component.name} context"

    component_list =
      child_sessions
      |> Enum.map(fn session ->
        component = CodeMySpec.Repo.preload(session, :component).component
        "- #{component.name}"
      end)
      |> Enum.join("\n")

    """
    #{title}

    #{component_list}

    🤖 Generated with [Claude Code](https://claude.com/claude-code)

    Co-Authored-By: Claude <noreply@anthropic.com>
    """
    |> String.trim()
  end
end
