defmodule CodeMySpec.ContextDesignSessions.Steps.GenerateContextDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.{Rules, Agents, Utils, Stories}
  alias CodeMySpec.Sessions.Session
  alias CodeMySpec.Documents.{ContextDesign, DocumentSpecProjector}

  def get_command(scope, %Session{project: project, component: component}, _opts \\ []) do
    with {:ok, rules} <- get_design_rules(scope),
         stories <- Stories.list_component_stories(scope, component.id),
         {:ok, prompt} <- build_design_prompt(project, component, rules, stories),
         {:ok, agent} <-
           Agents.create_agent(:context_designer, "context-design-generator", :claude_code),
         {:ok, command} <- Agents.build_command(agent, prompt) do
      [command_string, pipe] = command
      {:ok, Command.new(__MODULE__, command_string, pipe)}
    end
  end

  def handle_result(_scope, _session, result, _opts \\ []) do
    {:ok, %{}, result}
  end

  defp get_design_rules(scope) do
    case Rules.find_matching_rules(scope, "context", "design") do
      rules when is_list(rules) -> {:ok, rules}
      error -> error
    end
  end

  defp build_design_prompt(project, context, rules, stories) do
    rules_text = Enum.map_join(rules, "\n\n", & &1.content)
    stories_text = format_stories(stories)
    document_spec = DocumentSpecProjector.project_spec(ContextDesign)
    %{design_file: design_file_path} = Utils.component_files(context, project)

    prompt = """
    Generate a Phoenix context design for the following:

    Project: #{project.name}
    Project Description: #{project.description}
    Context Name: #{context.name}
    Context Description: #{context.description || "No description provided"}
    Type: #{context.type}

    User Stories this context satisfies:
    #{stories_text}

    Document Specification:
    #{document_spec}

    Design Rules:
    #{rules_text}

    Please write the design documentation to: #{design_file_path}
    """

    {:ok, prompt}
  end

  defp format_stories([]), do: "No user stories provided"

  defp format_stories(stories) do
    stories
    |> Enum.with_index(1)
    |> Enum.map_join("\n\n", fn {story, index} ->
      acceptance_criteria =
        case story.acceptance_criteria do
          [] -> "  None specified"
          criteria -> Enum.map_join(criteria, "\n", &"  - #{&1}")
        end

      """
      Story #{index}: #{story.title}
      Description: #{story.description}
      Acceptance Criteria:
      #{acceptance_criteria}
      """
      |> String.trim()
    end)
  end
end
