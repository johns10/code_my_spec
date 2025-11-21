defmodule CodeMySpec.GitHub do
  @moduledoc """
  GitHub API operations using provided access tokens.

  This context provides a thin authentication wrapper around the `oapi_github` library.
  It retrieves GitHub access tokens from the Integrations context and passes them to
  GitHub API operations, enabling scoped GitHub access.

  This context does not manage authentication or persist repository state—it simply
  bridges user scope to authenticated API calls.

  ## Supported Operations

  ### Repository Operations
  - Create, read, update, delete repositories
  - List repositories for authenticated user

  ### Content Operations
  - Get file/directory content
  - Create or update files
  - Delete files
  """

  alias CodeMySpec.Integrations
  alias CodeMySpec.Users.Scope

  # Repository Operations

  @doc """
  Creates a new repository for the authenticated user.

  ## Parameters
  - `scope` - User scope for multi-tenant isolation
  - `attrs` - Repository attributes (name, description, private, etc.)

  ## Examples

      iex> create_repository(scope, %{name: "my-repo", private: true})
      {:ok, %GitHub.Repository{}}

      iex> create_repository(scope, %{})
      {:error, :github_not_connected}
  """
  @spec create_repository(Scope.t(), map()) ::
          {:ok, GitHub.Repository.t()} | {:error, term()}
  def create_repository(%Scope{} = scope, attrs) do
    with {:ok, token} <- get_auth(scope) do
      GitHub.Repos.create_for_authenticated_user(attrs, auth: token)
    end
  end

  @doc """
  Retrieves a repository by owner and name.

  ## Parameters
  - `scope` - User scope for multi-tenant isolation
  - `owner` - Repository owner username
  - `repo` - Repository name

  ## Examples

      iex> get_repository(scope, "octocat", "Hello-World")
      {:ok, 200, %GitHub.Repository{}}
  """
  @spec get_repository(Scope.t(), String.t(), String.t()) ::
          {:ok, integer(), GitHub.Repository.t()} | {:error, term()}
  def get_repository(%Scope{} = scope, owner, repo) do
    with {:ok, token} <- get_auth(scope) do
      GitHub.Repos.get(owner, repo, auth: token)
    end
  end

  @doc """
  Lists repositories for the authenticated user.

  ## Parameters
  - `scope` - User scope for multi-tenant isolation
  - `opts` - Query options (type, sort, direction, per_page, page)

  ## Examples

      iex> list_repositories_for_authenticated_user(scope, type: "private")
      {:ok, 200, [%GitHub.Repository{}]}
  """
  @spec list_repositories_for_authenticated_user(Scope.t(), keyword()) ::
          {:ok, integer(), [GitHub.Repository.t()]} | {:error, term()}
  def list_repositories_for_authenticated_user(%Scope{} = scope, opts \\ []) do
    with {:ok, token} <- get_auth(scope) do
      GitHub.Repos.list_for_authenticated_user(opts ++ [auth: token])
    end
  end

  @doc """
  Updates a repository's properties.

  ## Parameters
  - `scope` - User scope for multi-tenant isolation
  - `owner` - Repository owner username
  - `repo` - Repository name
  - `attrs` - Attributes to update (name, description, private, etc.)

  ## Examples

      iex> update_repository(scope, "octocat", "Hello-World", %{description: "New description"})
      {:ok, 200, %GitHub.Repository{}}
  """
  @spec update_repository(Scope.t(), String.t(), String.t(), map()) ::
          {:ok, integer(), GitHub.Repository.t()} | {:error, term()}
  def update_repository(%Scope{} = scope, owner, repo, attrs) do
    with {:ok, token} <- get_auth(scope) do
      GitHub.Repos.update(owner, repo, attrs, auth: token)
    end
  end

  @doc """
  Deletes a repository.

  ## Parameters
  - `scope` - User scope for multi-tenant isolation
  - `owner` - Repository owner username
  - `repo` - Repository name

  ## Examples

      iex> delete_repository(scope, "octocat", "Hello-World")
      {:ok, 204, nil}
  """
  @spec delete_repository(Scope.t(), String.t(), String.t()) ::
          {:ok, integer(), any()} | {:error, term()}
  def delete_repository(%Scope{} = scope, owner, repo) do
    with {:ok, token} <- get_auth(scope) do
      GitHub.Repos.delete(owner, repo, auth: token)
    end
  end

  # Content Operations

  @doc """
  Gets file or directory content from a repository.

  ## Parameters
  - `scope` - User scope for multi-tenant isolation
  - `owner` - Repository owner username
  - `repo` - Repository name
  - `path` - File or directory path
  - `opts` - Query options (ref for branch/commit/tag)

  ## Examples

      iex> get_content(scope, "octocat", "Hello-World", "README.md")
      {:ok, 200, %GitHub.ContentFile{}}

      iex> get_content(scope, "octocat", "Hello-World", "src", ref: "develop")
      {:ok, 200, %GitHub.ContentFile{}}
  """
  @spec get_content(Scope.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, integer(),
           GitHub.Content.File.t()
           | GitHub.Content.Submodule.t()
           | GitHub.Content.Symlink.t()
           | GitHub.Content.Tree.t()
           | [map()]}
          | {:error, term()}
  def get_content(%Scope{} = scope, owner, repo, path, opts \\ []) do
    with {:ok, token} <- get_auth(scope) do
      GitHub.Repos.get_content(owner, repo, path, opts ++ [auth: token])
    end
  end

  @doc """
  Creates a new file or updates an existing file in a repository.

  ## Parameters
  - `scope` - User scope for multi-tenant isolation
  - `owner` - Repository owner username
  - `repo` - Repository name
  - `path` - File path (creates parent directories automatically)
  - `params` - Commit parameters:
    - `message` (required) - Commit message
    - `content` (required) - Base64 encoded file content
    - `sha` - File SHA (required for updates)
    - `branch` - Branch name (defaults to repository default branch)
    - `committer` - Committer information
    - `author` - Author information

  ## Examples

      # Create new file
      iex> create_or_update_file_contents(scope, "octocat", "Hello-World", "docs/README.md", %{
        message: "Add README",
        content: Base.encode64("# Hello World")
      })
      {:ok, 201, %GitHub.FileCommit{}}

      # Update existing file
      iex> create_or_update_file_contents(scope, "octocat", "Hello-World", "README.md", %{
        message: "Update README",
        content: Base.encode64("# Updated"),
        sha: "abc123..."
      })
      {:ok, 200, %GitHub.FileCommit{}}
  """
  @spec create_or_update_file_contents(Scope.t(), String.t(), String.t(), String.t(), map()) ::
          {:ok, GitHub.FileCommit.t()} | {:error, term()}
  def create_or_update_file_contents(%Scope{} = scope, owner, repo, path, params) do
    with {:ok, token} <- get_auth(scope) do
      GitHub.Repos.create_or_update_file_contents(owner, repo, path, params, auth: token)
    end
  end

  @doc """
  Deletes a file from a repository.

  ## Parameters
  - `scope` - User scope for multi-tenant isolation
  - `owner` - Repository owner username
  - `repo` - Repository name
  - `path` - File path to delete
  - `params` - Commit parameters:
    - `message` (required) - Commit message
    - `sha` (required) - File SHA to delete
    - `branch` - Branch name (defaults to repository default branch)
    - `committer` - Committer information
    - `author` - Author information

  ## Examples

      iex> delete_file(scope, "octocat", "Hello-World", "old-file.txt", %{
        message: "Remove old file",
        sha: "abc123..."
      })
      {:ok, 200, %GitHub.FileCommit{}}
  """
  @spec delete_file(Scope.t(), String.t(), String.t(), String.t(), map()) ::
          {:ok, integer(), GitHub.FileCommit.t()} | {:error, term()}
  def delete_file(%Scope{} = scope, owner, repo, path, params) do
    with {:ok, token} <- get_auth(scope) do
      GitHub.Repos.delete_file(owner, repo, path, params, auth: token)
    end
  end

  # Private Helpers

  defp get_auth(%Scope{} = scope) do
    case Integrations.get_integration(scope, :github) do
      {:ok, integration} -> {:ok, integration.access_token}
      {:error, :not_found} -> {:error, :github_not_connected}
    end
  end
end
