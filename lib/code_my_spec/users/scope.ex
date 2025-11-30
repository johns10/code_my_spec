defmodule CodeMySpec.Users.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `CodeMySpec.Users.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias CodeMySpec.Projects.Project
  alias CodeMySpec.Accounts.Account
  alias CodeMySpec.Users.User
  alias CodeMySpec.UserPreferences

  defstruct user: nil,
            active_account: nil,
            active_account_id: nil,
            active_project: nil,
            active_project_id: nil

  @type t :: %__MODULE__{
          user: User.t() | nil,
          active_account: Account.t() | nil,
          active_account_id: integer() | nil,
          active_project: Project.t() | nil,
          active_project_id: Ecto.UUID.t() | nil
        }

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    scope = %__MODULE__{user: user}

    case UserPreferences.get_user_preference(scope) do
      {:ok, preferences} ->
        %__MODULE__{
          user: user,
          active_account: preferences.active_account,
          active_account_id: preferences.active_account_id,
          active_project: preferences.active_project,
          active_project_id: preferences.active_project_id
        }

      {:error, :not_found} ->
        scope
    end
  end

  def for_user(nil), do: nil

  @doc """
  Creates a scope for CLI context using local project from database.

  In CLI mode:
  - User is loaded from client_users table (or default struct if not logged in)
  - Account is nil (CLI doesn't use accounts)
  - Project ID comes from local .code_my_spec/config.yml file
  - Project struct is loaded from the database

  Returns nil if no project is configured. Run `/init` to set up a project.
  """
  def for_cli do
    with {:ok, project_id} <- CodeMySpecCli.Config.get_project_id(),
         %Project{} = project <- CodeMySpec.Repo.get(Project, project_id) do
      %__MODULE__{
        user: get_cli_user(),
        active_account: nil,
        active_account_id: nil,
        active_project: project,
        active_project_id: project_id
      }
    else
      _error ->
        nil
    end
  end

  # Get the CLI user (authenticated client_user or default struct)
  defp get_cli_user do
    case CodeMySpecCli.Config.get_current_user_email() do
      {:ok, email} ->
        # Try to find client_user by email
        CodeMySpec.Repo.get_by(CodeMySpec.ClientUsers.ClientUser, email: email) ||
          default_cli_user()

      {:error, _} ->
        default_cli_user()
    end
  end

  # Return a default CLI user struct (not inserted into DB)
  defp default_cli_user do
    %CodeMySpec.ClientUsers.ClientUser{
      id: 0,
      email: "cli@localhost",
      oauth_token: nil,
      oauth_refresh_token: nil,
      oauth_expires_at: nil
    }
  end
end
