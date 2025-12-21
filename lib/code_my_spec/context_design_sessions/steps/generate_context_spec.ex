defmodule CodeMySpec.ContextSpecSessions.Steps.GenerateContextSpec do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.{Utils, Stories, Components, Rules}
  alias CodeMySpec.Sessions.Session
  alias CodeMySpec.Sessions.Steps.Helpers
  alias CodeMySpec.Documents.{DocumentSpecProjector}

  def get_command(scope, %Session{project: project, component: component} = session, opts \\ []) do
    with {:ok, rules} <- get_design_rules(scope),
         similar <- Components.list_similar_components(scope, component),
         stories <- Stories.list_component_stories(scope, component.id),
         {:ok, prompt} <- build_design_prompt(project, component, rules, stories, similar),
         {:ok, command} <-
           Helpers.build_agent_command(
             __MODULE__,
             session,
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

  defp get_design_rules(_scope) do
    rules = Rules.find_matching_rules("context", "design")
    {:ok, rules}
  end

  defp build_design_prompt(project, context, rules, stories, similar_components) do
    rules_text = Enum.map_join(rules, "\n\n", & &1.content)
    stories_text = format_stories(stories)
    similar_text = format_similar_components(project, similar_components)
    document_spec = DocumentSpecProjector.project_spec(:context_spec)
    %{spec_file: spec_file_path} = Utils.component_files(context, project)

    prompt = """
    Your task is to generate a specification for a Phoenix bounded context.

    # Project

    Project: #{project.name}
    Project Description: #{project.description}

    # Bounded context

    Context Name: #{context.name}
    Context Description: #{context.description || "No description provided"}
    Type: #{context.type}

    # User Stories this context satisfies
    #{stories_text}

    # Similar Components
    #{similar_text}

    # How to write the document
    #{document_spec}

    # Design Rules
    #{rules_text}

    Please write the specification to: #{spec_file_path}
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
