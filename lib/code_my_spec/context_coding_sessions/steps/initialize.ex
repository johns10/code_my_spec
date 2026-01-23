defmodule CodeMySpec.ContextCodingSessions.Steps.Initialize do
  @moduledoc """
  Initialize step for context coding sessions.

  Prepares the development environment by creating a git branch for the context
  implementation session and setting up the working directory at the project root.
  """

  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.ContextCodingSessions.Utils
  alias CodeMySpec.Environments
  alias CodeMySpec.Sessions.{Command, Session}

  @doc """
  Generates the environment setup command for initializing a context coding session.

  ## Workflow

  1. Generate sanitized branch name from context component name
  2. Build environment attributes (branch_name, repo_url, working_dir)
  3. Delegate to Environments module for environment-specific setup command
  4. Return Command struct for execution

  ## Parameters

  - `scope` - User/account scope for authorization
  - `session` - Session struct with preloaded project and component associations
  - `opts` - Keyword options (currently unused)

  ## Returns

  - `{:ok, Command.t()}` - Command ready for execution
  - `{:error, String.t()}` - Error if command generation fails
  """
  @impl true
  def get_command(_scope, %Session{project: project} = session, _opts) do
    branch_name = Utils.branch_name(session)

    environment_attrs = %{
      branch_name: branch_name,
      repo_url: project.code_repo,
      working_dir: "."
    }

    command_string =
      Environments.environment_setup_command(session.environment_type, environment_attrs)

    command = Command.new(__MODULE__, command_string)

    {:ok, command}
  end

  @doc """
  Processes the result of the initialization command.

  Stores the branch name and initialization timestamp in the session state
  for use by subsequent steps (e.g., Finalize).

  ## Parameters

  - `scope` - User/account scope for authorization
  - `session` - Session struct with current state
  - `result` - Result struct from command execution
  - `opts` - Keyword options (currently unused)

  ## Returns

  - `{:ok, session_updates, result}` - Session updates map and unchanged result
  - `{:error, String.t()}` - Error if result handling fails
  """
  @impl true
  def handle_result(_scope, session, result, _opts) do
    branch_name = Utils.branch_name(session)

    session_updates = %{
      state:
        Map.merge(session.state || %{}, %{
          branch_name: branch_name,
          initialized_at: DateTime.utc_now()
        })
    }

    {:ok, session_updates, result}
  end
end
