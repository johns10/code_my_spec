defmodule CodeMySpec.ContextDesignSessions.Steps.GenerateContextDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.{Rules, Agents}
  alias CodeMySpec.Sessions.Session

  def get_command(scope, %Session{project: project, component: component}) do
    with {:ok, rules} <- get_design_rules(scope),
         {:ok, prompt} <- build_design_prompt(project, component, rules),
         {:ok, agent} <-
           Agents.create_agent(:context_designer, "context-design-generator", :claude_code),
         {:ok, command} <- Agents.build_command(agent, prompt) do
      command_string = Enum.join(command, " ")
      {:ok, Command.new(__MODULE__, command_string)}
    end
  end

  def handle_result(_scope, session, _result) do
    {:ok, session}
  end

  defp get_design_rules(scope) do
    case Rules.find_matching_rules(scope, "context", "context_design") do
      rules when is_list(rules) -> {:ok, rules}
      error -> error
    end
  end

  defp build_design_prompt(project, context, rules) do
    rules_text = Enum.map_join(rules, "\n\n", & &1.content)

    prompt = """
    "Generate a Phoenix context design for the following:

    Project: #{project.name}
    Description: #{project.description || "No description provided"}

    Context: #{context.name}
    Type: #{context.type}

    Design Rules:
    #{rules_text}"
    """

    {:ok, prompt}
  end
end
