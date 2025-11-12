defmodule CodeMySpec.ContextComponentsDesignSessions.Steps.Finalize do
  @moduledoc """
  Completes the context components design session by creating a pull request with all generated design documentation.
  Implements StepBehaviour to generate PR creation commands.
  """

  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.{Command, Result, Session}
  alias CodeMySpec.ContextComponentsDesignSessions.Utils

  @impl true
  def get_command(_scope, %Session{component: nil}, _opts) do
    {:error, "Context component not found in session"}
  end

  def get_command(_scope, %Session{component: component} = session, _opts) do
    branch_name = Utils.branch_name(session)
    sanitized_name = sanitize_name(component.name)
    review_file_path = "review/#{sanitized_name}_components_review.md"

    pr_title = "Add component designs for #{component.name} context"
    pr_body = build_pr_body(component.name)
    commit_message = build_commit_message(component.name)

    command_string =
      build_git_command(branch_name, review_file_path, pr_title, pr_body, commit_message)

    command =
      Command.new(__MODULE__, command_string,
        metadata: %{
          branch_name: branch_name,
          pr_url: nil
        }
      )

    {:ok, command}
  end

  @impl true
  def handle_result(_scope, session, %Result{status: :error} = result, _opts) do
    session_updates = %{
      status: :failed,
      state:
        Map.merge(session.state || %{}, %{
          finalized_at: DateTime.utc_now()
        })
    }

    {:ok, session_updates, result}
  end

  def handle_result(_scope, session, %Result{status: :warning} = result, _opts) do
    pr_url = extract_pr_url(result.stdout)

    session_updates = %{
      status: :complete,
      state:
        Map.merge(session.state || %{}, %{
          pr_url: pr_url,
          finalized_at: DateTime.utc_now()
        })
    }

    {:ok, session_updates, result}
  end

  def handle_result(_scope, session, %Result{status: :ok} = result, _opts) do
    pr_url = extract_pr_url(result.stdout)

    session_updates = %{
      status: :complete,
      state:
        Map.merge(session.state || %{}, %{
          pr_url: pr_url,
          finalized_at: DateTime.utc_now()
        })
    }

    {:ok, session_updates, result}
  end

  # Private Functions

  defp sanitize_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\-_]/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  defp build_pr_body(context_name) do
    """
    ## Summary

    Component designs generated for #{context_name} context.

    ## Generated Documentation

    This PR includes the component architecture designs for the #{context_name} context.

    🤖 Generated with [Claude Code](https://claude.com/claude-code)
    """
  end

  defp build_commit_message(context_name) do
    """
    Add component designs for #{context_name} context

    🤖 Generated with [Claude Code](https://claude.com/claude-code)

    Co-Authored-By: Claude <noreply@anthropic.com>
    """
  end

  defp build_git_command(branch_name, review_file_path, pr_title, pr_body, commit_message) do
    # Escape single quotes in strings for shell safety
    escaped_commit_message = String.replace(commit_message, "'", "'\\''")
    escaped_pr_body = String.replace(pr_body, "'", "'\\''")
    escaped_pr_title = String.replace(pr_title, "'", "'\\''")

    """
    git -C docs add #{review_file_path} && \
    git -C docs commit -m '#{escaped_commit_message}' && \
    git -C docs push -u origin #{branch_name} && \
    gh pr create --title '#{escaped_pr_title}' --body '#{escaped_pr_body}'
    """
    |> String.trim()
  end

  defp extract_pr_url(nil), do: nil
  defp extract_pr_url(""), do: nil

  defp extract_pr_url(stdout) do
    # Match GitHub PR URLs in the output
    case Regex.run(~r/https:\/\/github\.com\/[^\s]+\/pull\/\d+/, stdout) do
      [url] -> String.trim(url)
      nil -> nil
    end
  end
end
