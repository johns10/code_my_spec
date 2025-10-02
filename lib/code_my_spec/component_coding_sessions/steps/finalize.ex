defmodule CodeMySpec.ComponentCodingSessions.Steps.Finalize do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.Environments
  alias CodeMySpec.ComponentCodingSessions

  def get_command(
        _scope,
        %{environment: environment, component: component, project: project} = session,
        _opts \\ []
      ) do
    %{code_file: code_file, test_file: test_file} =
      CodeMySpec.Utils.component_files(component, project)

    code_file_name =
      code_file
      |> String.split("/")
      |> tl()
      |> Enum.join("/")

    test_file_name =
      test_file
      |> String.split("/")
      |> tl()
      |> Enum.join("/")

    attrs = %{
      branch_name: ComponentCodingSessions.Utils.branch_name(session),
      code_file_name: code_file_name,
      test_file_name: test_file_name,
      working_dir: ".",
      context_name: component.name,
      context_type: component.type
    }

    command_string = Environments.code_environment_teardown_command(environment, attrs)
    {:ok, Command.new(__MODULE__, command_string)}
  end

  def handle_result(_scope, _session, result, _opts \\ []) do
    {:ok, %{}, result}
  end
end
