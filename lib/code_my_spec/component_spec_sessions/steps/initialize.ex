defmodule CodeMySpec.ComponentSpecSessions.Steps.Initialize do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.Environments
  alias CodeMySpec.Sessions.Session
  alias CodeMySpec.ComponentSpecSessions.Utils

  @impl true
  def get_command(
        _scope,
        %Session{environment: environment, project: project} = session,
        _opts \\ []
      ) do
    attrs = %{
      branch_name: Utils.branch_name(session),
      repo_url: project.code_repo,
      working_dir: "docs"
    }

    command_string = Environments.environment_setup_command(environment, attrs)

    {:ok, Command.new(__MODULE__, command_string)}
  end

  @impl true
  def handle_result(_scope, _session, result, _opts \\ []) do
    {:ok, %{}, result}
  end
end
