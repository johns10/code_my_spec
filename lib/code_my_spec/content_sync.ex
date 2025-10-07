defmodule CodeMySpec.ContentSync do
  @moduledoc """
  Orchestrates the content sync pipeline from Git repository to database.

  Coordinates file watching, frontmatter parsing, content processing (markdown/HTML/HEEx),
  and atomic database transactions. Handles the 'delete all and recreate' sync strategy
  where flat files are the source of truth. Broadcasts PubSub events on sync completion
  for real-time LiveView updates.

  All operations are scoped to `account_id` and `project_id` from the provided scope.
  """

  alias CodeMySpec.{Projects, Content, Git}
  alias CodeMySpec.ContentSync.Sync
  alias CodeMySpec.Users.Scope

  @type sync_result :: %{
          total_files: integer(),
          successful: integer(),
          errors: integer(),
          duration_ms: integer(),
          content_types: %{blog: integer(), page: integer(), landing: integer()}
        }

  @doc """
  Syncs content from the project's Git repository to the database.

  ## Parameters

    - `scope` - User scope containing account and project information

  ## Returns

    - `{:ok, sync_result}` - Successful sync with statistics
    - `{:error, :project_not_found}` - Project doesn't exist or scope doesn't have access
    - `{:error, :no_content_repo}` - Project has no content_repo configured
    - `{:error, reason}` - Git clone failed or sync operation failed

  ## Process

  1. Validates scope has an active project
  2. Loads project to retrieve content_repo URL
  3. Creates temporary directory using Briefly
  4. Clones repository to temporary directory
  5. Syncs content from temporary directory to database
  6. Returns sync result (temp directory cleaned up automatically)

  ## Examples

      iex> sync_from_git(scope)
      {:ok, %{total_files: 10, successful: 9, errors: 1, ...}}

      iex> sync_from_git(scope_without_project)
      {:error, :no_active_project}
  """
  @spec sync_from_git(Scope.t()) :: {:ok, sync_result()} | {:error, term()}
  def sync_from_git(%Scope{active_project_id: nil}), do: {:error, :no_active_project}

  def sync_from_git(%Scope{} = scope) do
    with {:ok, project} <- load_project(scope),
         {:ok, repo_url} <- extract_content_repo(project),
         {:ok, temp_path} <- create_temp_directory(),
         {:ok, cloned_path} <- clone_repository(scope, repo_url, temp_path) do
      content_dir = Path.join(cloned_path, "content")
      Sync.sync_directory(scope, content_dir)
    end
  end

  @doc """
  Lists all content with error parse status for the given scope.

  ## Parameters

    - `scope` - User scope containing account and project information

  ## Returns

  List of content records where `parse_status` is `:error`

  ## Examples

      iex> list_content_errors(scope)
      [%Content{parse_status: :error, parse_errors: %{...}}, ...]

      iex> list_content_errors(scope_with_no_errors)
      []
  """
  @spec list_content_errors(Scope.t()) :: [Content.Content.t()]
  def list_content_errors(%Scope{} = scope) do
    Content.list_content_with_status(scope, %{parse_status: "error"})
  end

  # ============================================================================
  # Private Functions - Project and Repository Loading
  # ============================================================================

  @spec load_project(Scope.t()) :: {:ok, Projects.Project.t()} | {:error, :project_not_found}
  defp load_project(%Scope{} = scope) do
    case Projects.get_project(scope, scope.active_project_id) do
      {:ok, project} -> {:ok, project}
      {:error, :not_found} -> {:error, :project_not_found}
    end
  end

  @spec extract_content_repo(Projects.Project.t()) ::
          {:ok, String.t()} | {:error, :no_content_repo}
  defp extract_content_repo(%{content_repo: nil}), do: {:error, :no_content_repo}
  defp extract_content_repo(%{content_repo: ""}), do: {:error, :no_content_repo}
  defp extract_content_repo(%{content_repo: repo_url}), do: {:ok, repo_url}

  # ============================================================================
  # Private Functions - Git Operations
  # ============================================================================

  @spec create_temp_directory() :: {:ok, String.t()} | {:error, term()}
  defp create_temp_directory do
    case Briefly.create(directory: true) do
      {:ok, path} -> {:ok, path}
      error -> error
    end
  end

  @spec clone_repository(Scope.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  defp clone_repository(%Scope{} = scope, repo_url, temp_path) do
    Git.clone(scope, repo_url, temp_path)
  end
end
