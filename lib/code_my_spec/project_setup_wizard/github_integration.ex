defmodule CodeMySpec.ProjectSetupWizard.GithubIntegration do
  @moduledoc """
  Handles GitHub integration for ProjectSetupWizard.

  Responsible for:
  - Checking GitHub connection status
  - Initiating OAuth flow
  - Creating code and docs repositories
  - Initializing docs repository structure
  """

  alias CodeMySpec.{Integrations, Projects, GitHub}
  alias CodeMySpec.Projects.Project
  alias CodeMySpec.Users.Scope

  # ============================================================================
  # GitHub Connection
  # ============================================================================

  @doc """
  Checks if GitHub is connected for the scoped user.

  Delegates to Integrations.connected?/2 for user-scoped filtering.

  ## Examples

      iex> connected?(scope)
      true

      iex> connected?(scope)
      false
  """
  @spec connected?(Scope.t()) :: boolean()
  def connected?(%Scope{} = scope) do
    Integrations.connected?(scope, :github)
  end

  @doc """
  Initiates GitHub OAuth connection flow.

  Generates authorization URL and session parameters for OAuth callback.
  Delegates to Integrations.authorize_url/1 for provider-agnostic OAuth handling.

  ## Parameters
  - `scope` - User scope for multi-tenant isolation
  - `redirect_uri` - Callback URL after GitHub authorization

  ## Returns
  - `{:ok, %{url: String.t(), session_params: map()}}` - Authorization URL and session state
  - `{:error, term()}` - Provider configuration or network error

  ## Examples

      iex> authorize(scope, "http://localhost:4000/auth/github/callback")
      {:ok, %{url: "https://github.com/login/oauth/authorize?...", session_params: %{state: "..."}}}
  """
  @spec authorize(Scope.t(), redirect_uri :: String.t()) ::
          {:ok, %{url: String.t(), session_params: map()}} | {:error, term()}
  def authorize(%Scope{} = _scope, _redirect_uri) do
    Integrations.authorize_url(:github)
  end

  # ============================================================================
  # Repository Creation
  # ============================================================================

  @doc """
  Creates blank GitHub repository for code and updates project.

  Validates GitHub connection, sanitizes project name, creates repository,
  and updates project.code_repo with the repository URL.

  ## Parameters
  - `scope` - User scope for authentication and multi-tenant isolation
  - `project` - Project to create repository for

  ## Returns
  - `{:ok, Project.t()}` - Updated project with code_repo configured
  - `{:error, :github_not_connected}` - GitHub integration not found
  - `{:error, term()}` - GitHub API or database error

  ## Examples

      iex> create_code_repo(scope, project)
      {:ok, %Project{code_repo: "https://github.com/username/my-project-code"}}

      iex> create_code_repo(scope, project)
      {:error, :github_not_connected}
  """
  @spec create_code_repo(Scope.t(), Project.t()) :: {:ok, Project.t()} | {:error, term()}
  def create_code_repo(%Scope{} = scope, %Project{} = project) do
    with true <- connected?(scope) || {:error, :github_not_connected},
         sanitized_name <- sanitize_repo_name(project.name),
         repo_name <- sanitized_name <> "-code",
         repo_attrs <- build_repo_attrs(project, repo_name),
         {:ok, response} <- GitHub.create_repository(scope, repo_attrs),
         {:ok, updated_project} <-
           Projects.update_project(scope, project, %{code_repo: response.html_url}) do
      {:ok, updated_project}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :github_not_connected}
    end
  end

  @doc """
  Creates GitHub repository for docs with initial structure and updates project.

  Validates GitHub connection, sanitizes project name, creates repository,
  initializes with /content, /design, /rules directories and .gitignore,
  and updates project.docs_repo with the repository URL.

  ## Parameters
  - `scope` - User scope for authentication and multi-tenant isolation
  - `project` - Project to create repository for

  ## Repository Structure
  - `/content` - Project-specific content
  - `/design` - Component design documents
  - `/rules` - Project coding rules and conventions
  - `.gitignore` - Excludes local/ and .DS_Store

  ## Returns
  - `{:ok, Project.t()}` - Updated project with docs_repo configured
  - `{:error, :github_not_connected}` - GitHub integration not found
  - `{:error, term()}` - GitHub API or database error

  ## Examples

      iex> create_docs_repo(scope, project)
      {:ok, %Project{docs_repo: "https://github.com/username/my-project-docs"}}

      iex> create_docs_repo(scope, project)
      {:error, :github_not_connected}
  """
  @spec create_docs_repo(Scope.t(), Project.t()) :: {:ok, Project.t()} | {:error, term()}
  def create_docs_repo(%Scope{} = scope, %Project{} = project) do
    with true <- connected?(scope) || {:error, :github_not_connected},
         sanitized_name <- sanitize_repo_name(project.name),
         repo_name <- sanitized_name <> "-docs",
         repo_attrs <- build_repo_attrs(project, repo_name),
         {:ok, response} <- GitHub.create_repository(scope, repo_attrs),
         {owner, repo} <- extract_owner_and_repo(response.html_url),
         :ok <- initialize_docs_structure(scope, {owner, repo}),
         {:ok, updated_project} <-
           Projects.update_project(scope, project, %{docs_repo: response.html_url}) do
      {:ok, updated_project}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :github_not_connected}
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp sanitize_repo_name(project_name) do
    project_name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9-_]/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  defp build_repo_attrs(%Project{} = project, repo_name) do
    %{
      name: repo_name,
      description: project.description || "Repository for #{project.name}",
      private: true
    }
  end

  defp extract_owner_and_repo(html_url) do
    # Extract owner and repo from URL like "https://github.com/owner/repo"
    case String.split(html_url, "/") do
      [_, _, _, owner, repo | _] -> {owner, repo}
      _ -> {:error, :invalid_url}
    end
  end

  defp initialize_docs_structure(%Scope{} = scope, {owner, repo}) do
    # Create initial commit with directory structure
    # GitHub API requires at least one file to initialize, so we create README.md files

    files_to_create = [
      {"content/README.md", content_readme()},
      {"design/README.md", design_readme()},
      {"rules/README.md", rules_readme()},
      {".gitignore", gitignore_content()}
    ]

    # Create all files sequentially
    # Note: This creates multiple commits. For a single commit with multiple files,
    # we'd need to use the Git Data API (trees and commits)
    Enum.reduce_while(files_to_create, :ok, fn {path, content}, _acc ->
      params = %{
        message: "Initialize #{path}",
        content: Base.encode64(content)
      }

      case GitHub.create_or_update_file_contents(scope, owner, repo, path, params) do
        {:ok, _file_commit} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp content_readme do
    """
    # Content

    Project-specific content goes here.

    This directory is for content that is specific to your project, such as:
    - Marketing copy
    - User guides
    - Documentation resources
    """
  end

  defp design_readme do
    """
    # Design

    Component design documents go here.

    This directory contains architectural designs for Phoenix components:
    - Context designs
    - Schema definitions
    - API specifications
    - Data flow diagrams
    """
  end

  defp rules_readme do
    """
    # Rules

    Project coding rules and conventions go here.

    This directory contains:
    - Coding standards
    - Architecture decision records
    - Development workflows
    - Style guides
    """
  end

  defp gitignore_content do
    """
    # Local development files
    local/

    # macOS system files
    .DS_Store

    # Editor temporary files
    *~
    .*.swp
    """
  end
end
