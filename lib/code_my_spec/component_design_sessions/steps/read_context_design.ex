defmodule CodeMySpec.ComponentDesignSessions.Steps.ReadContextDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions
  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.Utils

  def get_command(_scope, %{component: component, project: project}) do
    parent_component = component.parent_component
    %{design_file: design_file_path} = Utils.component_files(parent_component, project)
    {:ok, Command.new(__MODULE__, "cat #{design_file_path}")}
  end

  def handle_result(scope, session, interaction) do
    context_design = interaction.result.stdout
    updated_state = Map.put(session.state || %{}, :context_design, context_design)
    Sessions.update_session(scope, session, %{state: updated_state})
  end
end
