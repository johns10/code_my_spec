defmodule CodeMySpec.ComponentTestSessions.Steps.Finalize do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.Environments
  alias CodeMySpec.ComponentTestSessions
  alias CodeMySpec.Utils

  def get_command(
        _scope,
        %{environment_type: environment, component: component, project: project} = session,
        _opts \\ []
      ) do
    %{test_file: test_file} =
      Utils.component_files(component, project)

    test_file_name =
      test_file
      |> String.split("/")
      |> tl()
      |> Enum.join("/")

    attrs = %{
      branch_name: ComponentTestSessions.Utils.branch_name(session),
      test_file_name: test_file_name,
      working_dir: "test",
      context_name: component.name,
      context_type: component.type
    }

    command_string = Environments.test_environment_teardown_command(environment, attrs)
    {:ok, Command.new(__MODULE__, command_string)}
  end

  def handle_result(_scope, _session, result, _opts \\ []) do
    {:ok, %{}, result}
  end
end
