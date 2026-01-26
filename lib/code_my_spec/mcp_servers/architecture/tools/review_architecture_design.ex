defmodule CodeMySpec.MCPServers.Architecture.Tools.ReviewArchitectureDesign do
  @moduledoc """
  Reviews current architecture design against best practices.

  Provides feedback on surface-to-domain separation, dependency flow,
  component organization, and alignment with user stories. References
  architecture view files for current system state.
  """

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Stories
  alias CodeMySpec.Components
  alias CodeMySpec.MCPServers.Architecture.ArchitectureMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
  end

  @impl true
  def execute(_params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame) do
      unsatisfied_stories = Stories.list_unsatisfied_stories(scope)
      components = Components.list_components_with_dependencies(scope)
      dependency_validation = Components.validate_dependency_graph(scope)

      metrics = calculate_architecture_metrics(components, dependency_validation)

      prompt = build_review_prompt(unsatisfied_stories, components, metrics)

      {:reply, ArchitectureMapper.prompt_response(prompt), frame}
    else
      {:error, reason} ->
        {:reply, ArchitectureMapper.error(reason), frame}
    end
  end

  defp build_review_prompt(unsatisfied_stories, components, metrics) do
    """
    ## Architecture Design Review

    **Architecture Views:**
    Review the current system state in these files:
    - `docs/architecture/overview.md` - Component overview with descriptions
    - `docs/architecture/dependency_graph.mmd` - Mermaid dependency visualization
    - `docs/architecture/namespace_hierarchy.md` - Namespace tree structure

    **Architecture Metrics:**
    #{format_metrics(metrics)}

    **Unsatisfied Stories:** #{length(unsatisfied_stories)} stories without assigned components
    #{format_unsatisfied_stories(unsatisfied_stories)}

    **Component Organization:**
    #{format_component_organization(components)}

    **Dependency Health:**
    #{format_dependency_health(metrics)}

    **Review Questions:**

    1. **Surface-to-Domain Separation:**
       - Are surface components (controllers, liveviews, CLI) properly separated from domain logic?
       - Do surface components delegate to contexts rather than containing business logic?

    2. **Dependency Flow:**
       - Do all dependencies flow inward (surface → domain)?
       - Are there any domain → surface dependencies that should be reversed?

    3. **Component Responsibilities:**
       - Does each component have a clear, focused responsibility?
       - Are there components with overlapping or unclear purposes?

    4. **Story Coverage:**
       - Are all user stories mapped to appropriate surface components?
       - Do any stories require new components to be created?

    5. **Architectural Issues:**
       - Are there circular dependencies that need resolution?
       - Are there orphaned components without clear purpose?
       - Are there missing domain contexts needed to support surface components?

    **Next Steps:**
    Focus on:
    - Mapping the #{length(unsatisfied_stories)} unsatisfied stories to surface components
    - Reviewing and resolving dependency issues if any were found
    - Ensuring clean separation between surface (interface) and domain (logic) layers
    - Creating spec files for any missing components identified in the review
    """
  end

  defp calculate_architecture_metrics(components, dependency_validation) do
    surface_types = ["controller", "liveview", "cli", "worker"]
    domain_types = ["context", "schema", "repository", "coordinator"]

    surface_components = Enum.filter(components, &(&1.type in surface_types))
    domain_components = Enum.filter(components, &(&1.type in domain_types))

    %{
      total_components: length(components),
      surface_components: length(surface_components),
      domain_components: length(domain_components),
      contexts: Enum.count(components, &(&1.type == "context")),
      circular_dependencies: calculate_cycles(dependency_validation),
      orphaned_components: Enum.count(components, &is_orphaned?/1)
    }
  end

  defp calculate_cycles(:ok), do: 0
  defp calculate_cycles({:error, cycles}), do: length(cycles)

  defp is_orphaned?(component) do
    # A component is orphaned if it has no incoming or outgoing dependencies
    # and isn't a root context
    incoming = component.incoming_dependencies || []
    outgoing = component.outgoing_dependencies || []

    Enum.empty?(incoming) and Enum.empty?(outgoing) and component.type != "context"
  end

  defp format_metrics(metrics) do
    """
    - Total Components: #{metrics.total_components}
    - Surface Components: #{metrics.surface_components} (controllers, liveviews, CLI, workers)
    - Domain Components: #{metrics.domain_components} (contexts, schemas, repositories)
    - Contexts: #{metrics.contexts}
    - Circular Dependencies: #{metrics.circular_dependencies} #{if metrics.circular_dependencies == 0, do: "✅", else: "❌"}
    - Orphaned Components: #{metrics.orphaned_components} #{if metrics.orphaned_components == 0, do: "✅", else: "⚠️"}
    """
  end

  defp format_unsatisfied_stories([]) do
    "All stories have been assigned to components ✅"
  end

  defp format_unsatisfied_stories(stories) do
    stories
    |> Enum.take(5)
    |> Enum.map_join("\n", fn story ->
      "- **#{story.title}**: #{String.slice(story.description || "", 0, 100)}..."
    end)
    |> then(fn formatted ->
      if length(stories) > 5 do
        "#{formatted}\n- ... and #{length(stories) - 5} more"
      else
        formatted
      end
    end)
  end

  defp format_component_organization(components) do
    if Enum.empty?(components) do
      "No components exist yet. Start by mapping user stories to surface components."
    else
      by_type =
        components
        |> Enum.group_by(& &1.type)
        |> Enum.sort_by(fn {type, _} -> component_type_order(type) end)

      by_type
      |> Enum.map_join("\n", fn {type, comps} ->
        "**#{String.capitalize(type)}s** (#{length(comps)}):\n" <>
          (comps
           |> Enum.take(5)
           |> Enum.map_join("\n", fn comp ->
             dep_count =
               case comp.outgoing_dependencies do
                 %Ecto.Association.NotLoaded{} -> 0
                 deps when is_list(deps) -> length(deps)
                 _ -> 0
               end

             "  - #{comp.name} (#{comp.module_name}) - #{dep_count} dependencies"
           end)
           |> then(fn formatted ->
             if length(comps) > 5 do
               "#{formatted}\n  - ... and #{length(comps) - 5} more"
             else
               formatted
             end
           end))
      end)
    end
  end

  defp component_type_order("controller"), do: 1
  defp component_type_order("liveview"), do: 2
  defp component_type_order("cli"), do: 3
  defp component_type_order("worker"), do: 4
  defp component_type_order("coordinator"), do: 5
  defp component_type_order("context"), do: 6
  defp component_type_order("repository"), do: 7
  defp component_type_order("schema"), do: 8
  defp component_type_order(_), do: 99

  defp format_dependency_health(%{circular_dependencies: 0}) do
    "No circular dependencies found ✅\n\nDependency graph is healthy. Ensure new dependencies maintain this clean state."
  end

  defp format_dependency_health(%{circular_dependencies: count}) do
    """
    #{count} circular dependencies detected ❌

    Circular dependencies violate clean architecture principles and make code harder to test and maintain.
    Use the ValidateDependencyGraph tool to identify specific cycles, then refactor to break them.
    """
  end
end
