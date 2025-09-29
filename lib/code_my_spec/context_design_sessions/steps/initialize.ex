defmodule CodeMySpec.ContextDesignSessions.Steps.Initialize do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.Environments
  alias CodeMySpec.ContextDesignSessions.Utils

  def get_command(_scope, %{environment: environment, project: project} = session) do
    attrs = %{
      branch_name: Utils.branch_name(session),
      repo_url: project.code_repo,
      working_dir: "docs"
    }

    command_string = Environments.environment_setup_command(environment, attrs)
    {:ok, Command.new(__MODULE__, command_string)}
  end

  def handle_result(_scope, _session, interaction) do
    {:ok, %{}, interaction}
  end
end
