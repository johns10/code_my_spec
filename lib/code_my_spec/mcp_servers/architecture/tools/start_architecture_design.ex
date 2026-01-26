defmodule CodeMySpec.McpServers.Architecture.Tools.StartArchitectureDesign do
  @moduledoc """
  Initiates guided architecture design session with surface-level component mapping.

  Maps user stories to application surface (controllers, liveviews, CLI modules)
  rather than abstract bounded contexts. References architecture view files
  for current system state.
  """

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Stories
  alias CodeMySpec.Components
  alias CodeMySpec.McpServers.Architecture.ArchitectureMapper
  alias CodeMySpec.McpServers.Validators

  schema do
  end

  @impl true
  def execute(_params, frame) do
    with {:ok, scope} <- Validators.validate_project_scope(frame) do
      stories = Stories.list_unsatisfied_stories(scope)
      components = Components.list_components_with_dependencies(scope)

      prompt = build_design_prompt(stories, components)

      {:reply, ArchitectureMapper.prompt_response(prompt), frame}
    else
      {:error, reason} ->
        {:reply, ArchitectureMapper.error(reason), frame}
    end
  end

  defp build_design_prompt(stories, components) do
    """
    You are an expert Elixir architect specializing in Phoenix context design.
    Your job is to map user stories to concrete application surface components.
    We will only focus on unsatisfied user stories for this conversation, so if there are no unsatisfied user stories, there's nothing to do.

    **Unsatisfied User Stories:**
    #{format_stories_context(stories)}

    **Existing Components:**
    #{format_components_context(components)}

    **Architecture Views:**
    Before designing, read these architecture view files to understand the current system:
    - `docs/architecture/overview.md` - Component overview with descriptions
    - `docs/architecture/dependency_graph.mmd` - Mermaid dependency visualization
    - `docs/architecture/namespace_hierarchy.md` - Namespace tree structure

    **Your Role:**
    Map each user story to application surface components based on the interface type:
    - **API endpoints** → Controllers (handle HTTP requests, return JSON/responses)
    - **UI features** → LiveViews (interactive web UI with real-time updates)
    - **CLI commands** → CLI modules (terminal interface, command processing)
    - **Background jobs** → Workers/GenServers (async processing, scheduled tasks)
    - **Domain logic** → Contexts (business logic, entity ownership)

    **Design Principles:**
    - Start at the surface: identify the entry point first (controller, liveview, CLI)
    - Each user story should map to at least one surface component
    - Surface components delegate to domain contexts for business logic
    - Keep separation between surface (interface) and domain (logic)
    - Dependencies should flow inward: surface → domain, never domain → surface
    - Avoid circular dependencies at all layers
    - Use coordination contexts for cross-domain workflows

    **Component Types:**
    - `liveview` - Interactive Phoenix LiveView components
    - `controller` - Phoenix controllers for API/HTTP endpoints
    - `cli` - Command-line interface modules
    - `context` - Phoenix contexts (domain logic, entity ownership)

    **Instructions:**
    1. Read the architecture view files listed above
    2. For each unsatisfied story, identify:
       - What type of interface it needs (API, UI, CLI)
       - Which surface component(s) will handle it
       - What domain contexts it depends on
       - Any new schemas or dependencies needed
    3. Create spec files for new components using the CreateSpec tool
    4. Update dependencies between components using UpdateSpecMetadata
    5. Maintain clear separation: surface → domain, never reverse

    Start by reviewing the existing stories and components above, then map each story to its surface component(s).
    Ask questions about interface requirements, workflow orchestration, and dependencies as needed.
    """
  end

  defp format_stories_context([]),
    do: "The requirements for all user stories have been satisfied."

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
    |> Enum.map(&"- #{&1.target_component.name}")
    |> Enum.join("\n")
  end
end
