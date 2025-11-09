defmodule CodeMySpec.ContextDesignSessions.Steps.GenerateContextDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.{Rules, Utils, Stories, Components}
  alias CodeMySpec.Sessions.{Session, Steps.Helpers}
  alias CodeMySpec.Documents.{ContextDesign, DocumentSpecProjector}

  def get_command(scope, %Session{project: project, component: component}, opts \\ []) do
    with {:ok, rules} <- get_design_rules(scope),
         similar_components <- Components.list_similar_components(scope, component),
         stories <- Stories.list_component_stories(scope, component.id),
         {:ok, prompt} <-
           build_design_prompt(project, component, rules, stories, similar_components),
         {:ok, command} <-
           Helpers.build_agent_command(
             __MODULE__,
             :context_designer,
             "context-design-generator",
             prompt,
             opts
           ) do
      {:ok, command}
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

  defp build_design_prompt(project, context, rules, stories, similar_components) do
    rules_text = Enum.map_join(rules, "\n\n", & &1.content)
    stories_text = format_stories(stories)
    similar_text = format_similar_components(project, similar_components)
    document_spec = DocumentSpecProjector.project_spec(:context)
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

    Similar Components (for design inspiration):
    #{similar_text}

    Document Specification:
    #{document_spec}

    Design Rules:
    #{rules_text}

    Please write the design documentation to: #{design_file_path}
    """

    {:ok, prompt}
  end

  defp format_similar_components(_project, []), do: "No similar components provided"

  defp format_similar_components(project, similar_components) do
    similar_components
    |> Enum.with_index(1)
    |> Enum.map_join("\n\n", fn {component, index} ->
      files = Utils.component_files(component, project)

      """
      #{index}. #{component.name} (#{component.type})
         Description: #{component.description || "No description"}
         Design: #{files.design_file}
         Implementation: #{files.code_file}
         Test: #{files.test_file}
      """
      |> String.trim()
    end)
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
