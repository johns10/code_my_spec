defmodule CodeMySpec.ContextDesignSessions.Steps.GenerateContextDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.{Rules, Agents, Utils}
  alias CodeMySpec.Sessions.Session

  def get_command(scope, %Session{project: project, component: component}) do
    with {:ok, rules} <- get_design_rules(scope),
         {:ok, prompt} <- build_design_prompt(project, component, rules),
         {:ok, agent} <-
           Agents.create_agent(:context_designer, "context-design-generator", :claude_code),
         {:ok, command} <- Agents.build_command(agent, prompt) do
      [command_string, pipe] = command
      {:ok, Command.new(__MODULE__, command_string, pipe)}
    end
  end

  def handle_result(_scope, _session, interaction) do
    {:ok, %{}, interaction}
  end

  defp get_design_rules(scope) do
    case Rules.find_matching_rules(scope, "context", "design") do
      rules when is_list(rules) -> {:ok, rules}
      error -> error
    end
  end

  defp build_design_prompt(project, context, rules) do
    rules_text = Enum.map_join(rules, "\n\n", & &1.content)
    %{design_file: design_file_path} = Utils.component_files(context, project)

    prompt = """
    "Generate a Phoenix context design for the following:

    Project: #{project.name}
    Project Description: #{project.description}
    Context Name: #{context.name}
    Context Description: #{context.description || "No description provided"}
    Type: #{context.type}

    Design Rules:
    #{rules_text}

    Please write the design documentation to: #{design_file_path}"
    """

    {:ok, prompt}
  end
end
