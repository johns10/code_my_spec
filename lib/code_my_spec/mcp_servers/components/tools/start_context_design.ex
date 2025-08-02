defmodule CodeMySpec.MCPServers.Components.Tools.StartContextDesign do
  @moduledoc "Initiates guided context design session"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Stories
  alias CodeMySpec.Components
  alias CodeMySpec.MCPServers.Components.ComponentsMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
  end

  @impl true
  def execute(_params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame) do
      stories = Stories.list_project_stories(scope)
      components = Components.list_components_with_dependencies(scope)

      prompt = """
      You are an expert Elixir architect specializing in Phoenix contexts.
      Your job is to design a clean context architecture that satisfies the user stories.

      **Current User Stories:**
      #{format_stories_context(stories)}

      **Existing Components:**
      #{format_components_context(components)}

      **Your Role:**
      - Map user stories to Phoenix contexts based on entity ownership
      - Use business capability grouping within entity boundaries  
      - Ensure flat context structure (no nested contexts)
      - Distinguish between domain contexts (own entities) and coordination contexts (orchestrate workflows)
      - Create components and dependencies to represent the complete system

      **Context Design Principles:**
      - Each user story should map to exactly one context
      - Domain contexts should own at least one entity type
      - Coordination contexts orchestrate workflows across domains
      - Dependencies should be explicit and justified
      - Avoid circular dependencies
      - Keep context responsibilities clear and focused

      **Instructions:**
      Start by reviewing the existing stories and components above, then guide me through creating or refining the context architecture.
      Ask questions about domain boundaries, entity ownership, and workflow orchestration needs.
      """

      {:reply, ComponentsMapper.prompt_response(prompt), frame}
    else
      {:error, atom} ->
        {:reply, ComponentsMapper.error(atom), frame}
    end
  end

  defp format_stories_context([]), do: "No stories currently exist for this project."

  defp format_stories_context(stories) do
    stories
    |> Enum.map(&format_story_summary/1)
    |> Enum.join("\n\n")
  end

  defp format_story_summary(story) do
    criteria =
      case story.acceptance_criteria do
        [] ->
          "No acceptance criteria defined"

        criteria ->
          criteria
          |> Enum.map(&"- #{&1}")
          |> Enum.join("\n")
      end

    """
    **#{story.title}**
    #{story.description}

    Acceptance Criteria:
    #{criteria}
    """
  end

  defp format_components_context([]), do: "No components currently exist for this project."

  defp format_components_context(components) do
    components
    |> Enum.map(&format_component_summary/1)
    |> Enum.join("\n\n")
  end

  defp format_component_summary(component) do
    dependencies = format_dependencies(component.outgoing_dependencies)

    """
    **#{component.name}** (#{component.type})
    Module: #{component.module_name}
    #{if component.description, do: "Description: #{component.description}", else: "No description"}

    Dependencies:
    #{dependencies}
    """
  end

  defp format_dependencies([]), do: "None"

  defp format_dependencies(dependencies) do
    dependencies
    |> Enum.map(&"- #{&1.type}: #{&1.target_component.name}")
    |> Enum.join("\n")
  end
end