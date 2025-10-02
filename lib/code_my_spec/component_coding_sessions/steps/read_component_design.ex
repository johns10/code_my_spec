defmodule CodeMySpec.ComponentCodingSessions.Steps.ReadComponentDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.Utils

  @impl true
  def get_command(_scope, %{component: component, project: project}, _opts \\ []) do
    %{design_file: design_file_path} = Utils.component_files(component, project)
    {:ok, Command.new(__MODULE__, "cat #{design_file_path}")}
  end

  @impl true
  def handle_result(_scope, session, result, _opts \\ []) do
    component_design = result.stdout
    updated_state = Map.put(session.state || %{}, "component_design", component_design)
    {:ok, %{state: updated_state}, result}
  end
end
