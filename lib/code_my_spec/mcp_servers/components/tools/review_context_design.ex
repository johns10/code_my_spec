defmodule CodeMySpec.MCPServers.Components.Tools.ReviewContextDesign do
  @moduledoc "Reviews current context design against best practices and provides architectural feedback"

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
      unsatisfied_stories = Stories.list_unsatisfied_stories(scope)
      architecture = Components.show_architecture(scope)
      dependency_validation = Components.validate_dependency_graph(scope)

      prompt = """
      ## Context Design Review

      **Current Architecture:**
      #{format_architecture(architecture)}

      **Unsatisfied Stories:** #{length(unsatisfied_stories)} stories without assigned components
      #{format_unsatisfied_stories(unsatisfied_stories)}

      **Dependency Analysis:**
      #{format_dependency_analysis(dependency_validation)}

      **Review Questions:**
      1. Are the context boundaries aligned with business capabilities?
      2. Do any contexts have unclear or overlapping responsibilities?
      3. Are there missing contexts needed to satisfy the user stories?
      4. Are dependencies properly justified and non-circular?
      5. Should any contexts be split or merged based on cohesion?

      **Next Steps:**
      Focus on:
      - Assigning contexts to the #{length(unsatisfied_stories)} unsatisfied stories
      - Reviewing dependency issues if any were found
      - Ensuring each context has clear ownership boundaries

      Would you like me to provide specific recommendations for any of these areas?
      """

      {:reply, ComponentsMapper.prompt_response(prompt), frame}
    else
      {:error, atom} ->
        {:reply, ComponentsMapper.error(atom), frame}
    end
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

  defp format_dependency_analysis(:ok), do: "No circular dependencies found ✅"

  defp format_dependency_analysis({:error, cycles}),
    do: "#{length(cycles)} circular dependencies detected ❌"

  defp format_architecture([]) do
    "No components defined yet"
  end

  defp format_architecture(architecture) do
    architecture
    |> Enum.map(fn %{component: component, depth: depth} ->
      indent = String.duplicate("  ", depth)
      stories_count = length(component.stories || [])
      "#{indent}- **#{component.name}** (#{component.type}) - #{stories_count} stories"
    end)
    |> Enum.join("\n")
  end
end
