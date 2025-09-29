defmodule CodeMySpec.ContextDesignSessions.Steps.Finalize do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.Environments
  alias CodeMySpec.ContextDesignSessions

  def get_command(
        _scope,
        %{environment: environment, component: component, project: project} = session
      ) do
    %{design_file: design_file} = CodeMySpec.Utils.component_files(component, project)

    design_file_name =
      design_file
      |> String.split("/")
      |> tl()
      |> Enum.join("/")

    attrs = %{
      branch_name: ContextDesignSessions.Utils.branch_name(session),
      design_file_name: design_file_name,
      working_dir: "docs",
      context_name: component.name
    }

    command_string = Environments.docs_environment_teardown_command(environment, attrs)
    {:ok, Command.new(__MODULE__, command_string)}
  end

  def handle_result(_scope, _session, interaction) do
    {:ok, %{}, interaction}
  end
end
