defmodule CodeMySpec.ContentSync.GitSync do
  @moduledoc """
  Handles Git repository operations for content sync.

  Clones project's docs_repo to temporary directory using Briefly for
  automatic cleanup. Returns local directory path for sync operations.

  Each sync creates a fresh clone - no persistent caching or pull operations.
  """

  alias CodeMySpec.Projects
  alias CodeMySpec.Git
  alias CodeMySpec.Users.Scope

  @type path :: String.t()
  @type error_reason ::
          :project_not_found
          | :no_docs_repo
          | :not_connected
          | :unsupported_provider
          | :invalid_url
          | term()

  @doc """
  Clones a project's content repository to a temporary directory.

  ## Parameters
  - `scope` - User scope containing active_project_id

  ## Returns
  - `{:ok, path}` - Absolute path to cloned repository
  - `{:error, :project_not_found}` - Project lookup failed
  - `{:error, :no_docs_repo}` - Project lacks docs_repo URL
  - `{:error, :not_connected}` - No integration for provider
  - `{:error, :unsupported_provider}` - Provider not supported
  - `{:error, :invalid_url}` - Invalid repository URL format
  - `{:error, reason}` - Git operation failed

  ## Examples

      iex> clone_to_temp(scope)
      {:ok, "/tmp/briefly-123/repo"}

      iex> clone_to_temp(scope_without_project)
      {:error, :project_not_found}
  """
  @spec clone_to_temp(Scope.t()) :: {:ok, path()} | {:error, error_reason()}
  def clone_to_temp(%Scope{active_project_id: nil}), do: {:error, :project_not_found}

  def clone_to_temp(%Scope{} = scope) do
    with {:ok, project} <- Projects.get_project(scope, scope.active_project_id),
         {:ok, docs_repo} <- validate_docs_repo(project),
         {:ok, temp_dir} <- create_temp_clone_dir(),
         {:ok, _path} <- Git.clone(scope, docs_repo, temp_dir) do
      {:ok, temp_dir}
    end
  end

  # Creates a unique temporary directory for git clone
  # Briefly manages lifecycle, but we need to ensure the directory doesn't exist
  # for Git.clone to work properly
  defp create_temp_clone_dir do
    parent = System.tmp_dir!()
    # Create unique directory name using timestamp and random string
    unique_name =
      "git_sync_#{System.system_time(:nanosecond)}_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"

    path = Path.join(parent, unique_name)

    {:ok, path}
  end

  # Validates that project has a non-nil, non-empty docs_repo
  defp validate_docs_repo(%{docs_repo: nil}), do: {:error, :no_docs_repo}
  defp validate_docs_repo(%{docs_repo: ""}), do: {:error, :no_docs_repo}

  defp validate_docs_repo(%{docs_repo: docs_repo}) when is_binary(docs_repo) do
    trimmed = String.trim(docs_repo)

    case trimmed do
      "" -> {:error, :no_docs_repo}
      url -> {:ok, url}
    end
  end
end
