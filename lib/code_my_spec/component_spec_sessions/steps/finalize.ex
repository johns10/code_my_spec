defmodule CodeMySpec.ComponentSpecSessions.Steps.Finalize do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.Environments
  alias CodeMySpec.ComponentSpecSessions

  def get_command(
        _scope,
        %{environment: environment, component: component, project: project} = session,
        _opts \\ []
      ) do
    %{design_file: design_file} = CodeMySpec.Utils.component_files(component, project)

    design_file_name =
      design_file
      |> String.split("/")
      |> tl()
      |> Enum.join("/")

    attrs = %{
      branch_name: ComponentSpecSessions.Utils.branch_name(session),
      design_file_name: design_file_name,
      working_dir: "docs",
      context_name: component.name,
      context_type: component.type
    }

    command_string = Environments.docs_environment_teardown_command(environment, attrs)
    {:ok, Command.new(__MODULE__, command_string)}
  end

  def handle_result(_scope, _session, result, _opts \\ []) do
    {:ok, %{}, result}
  end
end
