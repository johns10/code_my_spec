defmodule CodeMySpec.ProjectSetupWizard do
  @moduledoc """
  Stateless coordination context for project environment setup.

  Orchestrates GitHub integration, repository creation with initialization,
  VS Code extension presence tracking, and setup script generation.

  ## Responsibilities
  - Coordinate GitHub OAuth connection flow
  - Create code repositories (blank)
  - Create docs repositories (initialized with directory structure)
  - Configure project repository URLs
  - Generate bash setup scripts for Phoenix project initialization
  - Track VS Code extension presence via Phoenix.Presence
  - Aggregate setup completion status

  ## Design Principles
  - Stateless orchestration - no dedicated wizard tables
  - Pure delegation - no business logic duplication
  - Fail-fast validation - verify preconditions before operations
  - Real-time presence - no database persistence for extension tracking
  """

  alias CodeMySpec.{Projects}
  alias CodeMySpec.Projects.Project
  alias CodeMySpec.Users.Scope
  alias CodeMySpec.ProjectSetupWizard.GithubIntegration
  alias CodeMySpec.ProjectSetupWizard.ScriptGenerator

  @type setup_status :: %{
          github_connected: boolean(),
          code_repo_configured: boolean(),
          docs_repo_configured: boolean(),
          vscode_extension_connected: boolean(),
          setup_complete: boolean()
        }

  # ============================================================================
  # GitHub Integration - Delegated to GithubIntegration
  # ============================================================================

  defdelegate github_connected?(scope), to: GithubIntegration, as: :connected?
  defdelegate connect_github(scope, redirect_uri), to: GithubIntegration, as: :authorize
  defdelegate create_code_repo(scope, project), to: GithubIntegration
  defdelegate create_docs_repo(scope, project), to: GithubIntegration

  @doc """
  Configures project repository URLs.

  Validates repository URLs and delegates persistence to Projects context.
  Respects scope account_id filtering through Projects.update_project/3.

  ## Parameters
  - `scope` - User scope for multi-tenant isolation
  - `project` - Project to configure
  - `repo_urls` - Map with :code_repo and/or :docs_repo keys

  ## Returns
  - `{:ok, Project.t()}` - Updated project with configured URLs
  - `{:error, Ecto.Changeset.t()}` - Validation errors (invalid URLs, etc.)

  ## Examples

      iex> configure_repositories(scope, project, %{code_repo: "https://github.com/owner/repo.git"})
      {:ok, %Project{code_repo: "https://github.com/owner/repo.git"}}

      iex> configure_repositories(scope, project, %{code_repo: "invalid-url"})
      {:error, %Ecto.Changeset{}}
  """
  @spec configure_repositories(Scope.t(), Project.t(), map()) ::
          {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def configure_repositories(%Scope{} = scope, %Project{} = project, repo_urls) do
    Projects.update_project(scope, project, repo_urls)
  end

  # ============================================================================
  # Script Generation - Delegated to ScriptGenerator
  # ============================================================================

  defdelegate generate_setup_script(project), to: ScriptGenerator, as: :generate

  # ============================================================================
  # VS Code Extension Presence
  # ============================================================================

  @doc """
  Checks if VS Code extension is connected for user.

  Queries Phoenix.Presence for real-time extension presence.
  No database persistence - entirely in-memory via Presence.

  ## Parameters
  - `scope` - User scope to check extension presence for

  ## Returns
  - `true` - Extension is connected and tracking presence
  - `false` - No extension connected

  ## Examples

      iex> vscode_extension_connected?(scope)
      false

      iex> vscode_extension_connected?(scope)
      true
  """
  @spec vscode_extension_connected?(Scope.t()) :: boolean()
  def vscode_extension_connected?(%Scope{user: %{id: user_id}}) do
    # Check Presence for user:#{user_id} topic
    # Phoenix.Presence.list returns empty map if no presences
    topic = "vscode:user"

    case CodeMySpecWeb.Presence.list(topic) do
      presences when map_size(presences) > 0 ->
        # Check if this specific user is present
        Map.has_key?(presences, "user:#{user_id}")

      empty ->
        false
    end
  rescue
    # If Presence module doesn't exist or errors, return false
    _ -> false
  end

  # ============================================================================
  # Setup Status Aggregation
  # ============================================================================

  @doc """
  Aggregates setup completion status for project.

  Checks all setup components:
  - GitHub integration via Integrations context
  - Code repository URL configuration
  - Docs repository URL configuration
  - VS Code extension presence via Phoenix.Presence

  Setup is complete when all four components are configured.

  ## Parameters
  - `scope` - User scope for GitHub connection check
  - `project` - Project to check setup status for

  ## Returns
  - `setup_status()` - Map with boolean flags for each component and overall completion

  ## Examples

      iex> get_setup_status(scope, fully_configured_project)
      %{
        github_connected: true,
        code_repo_configured: true,
        docs_repo_configured: true,
        vscode_extension_connected: true,
        setup_complete: true
      }

      iex> get_setup_status(scope, partial_project)
      %{
        github_connected: false,
        code_repo_configured: true,
        docs_repo_configured: false,
        vscode_extension_connected: false,
        setup_complete: false
      }
  """
  @spec get_setup_status(Scope.t(), Project.t()) :: setup_status()
  def get_setup_status(%Scope{} = scope, %Project{} = project) do
    github_connected = github_connected?(scope)
    code_repo_configured = not is_nil(project.code_repo)
    docs_repo_configured = not is_nil(project.docs_repo)
    vscode_extension_connected = vscode_extension_connected?(scope)

    setup_complete =
      github_connected and code_repo_configured and docs_repo_configured and
        vscode_extension_connected

    %{
      github_connected: github_connected,
      code_repo_configured: code_repo_configured,
      docs_repo_configured: docs_repo_configured,
      vscode_extension_connected: vscode_extension_connected,
      setup_complete: setup_complete
    }
  end
end
