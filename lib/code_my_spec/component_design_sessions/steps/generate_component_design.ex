defmodule CodeMySpec.ComponentDesignSessions.Steps.GenerateComponentDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.{Rules, Agents, Utils}
  alias CodeMySpec.Sessions.Session

  def get_command(scope, %Session{project: project, component: component, state: state}) do
    with {:ok, rules} <- get_design_rules(scope, component),
         {:ok, prompt} <- build_design_prompt(project, component, rules, state),
         {:ok, agent} <-
           Agents.create_agent(:component_designer, "component-design-generator", :claude_code),
         {:ok, command} <- Agents.build_command(agent, prompt) do
      [command_string, pipe] = command
      {:ok, Command.new(__MODULE__, command_string, pipe)}
    end
  end

  def handle_result(_scope, _session, result) do
    {:ok, %{}, result}
  end

  defp get_design_rules(scope, component) do
    component_type = component.type || "other"

    case Rules.find_matching_rules(scope, Atom.to_string(component_type), "design") do
      rules when is_list(rules) -> {:ok, rules}
      error -> error
    end
  end

  defp build_design_prompt(project, component, rules, state) do
    rules_text = Enum.map_join(rules, "\n\n", & &1.content)
    context_design = get_context_design(state)
    %{design_file: design_file_path} = Utils.component_files(component, project)

    prompt = """
    Generate a Phoenix component design for the following:

    Project: #{project.name}
    Project Description: #{project.description}
    Component Name: #{component.name}
    Component Description: #{component.description || "No description provided"}
    Type: #{component.type}

    Parent Context Design:
    #{context_design}

    Design Rules:
    #{rules_text}

    Please write the design documentation to: #{design_file_path}
    """

    {:ok, prompt}
  end

  defp get_context_design(%{"context_design" => context_design}) when is_binary(context_design),
    do: context_design

  defp get_context_design(_state), do: "No context design available"
end
