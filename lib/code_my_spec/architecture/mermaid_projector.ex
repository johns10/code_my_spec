defmodule CodeMySpec.Architecture.MermaidProjector do
  @moduledoc """
  Generates a simple Mermaid flowchart showing contexts and their dependency relationships.
  """

  alias CodeMySpec.Components.Component

  @doc """
  Generates a Mermaid flowchart showing contexts and their dependencies.

  ## Parameters
    - components: List of Component structs

  ## Returns
    - String containing Mermaid flowchart syntax
  """
  @spec project([Component.t()]) :: String.t()
  def project(components) do
    components
    |> filter_contexts()
    |> build_flowchart()
  end

  defp filter_contexts(components) do
    Enum.filter(components, &(&1.type == "context"))
  end

  defp build_flowchart([]), do: "flowchart TD"

  defp build_flowchart(contexts) do
    nodes = build_nodes(contexts)
    edges = build_edges(contexts)

    ["flowchart TD" | nodes ++ edges]
    |> Enum.join("\n")
  end

  defp build_nodes(contexts) do
    Enum.map(contexts, &build_node/1)
  end

  defp build_node(%{module_name: module_name}) do
    sanitized_id = sanitize_module_name(module_name)
    "#{sanitized_id}[#{module_name}]"
  end

  defp build_edges(contexts) do
    contexts
    |> Enum.flat_map(&build_edges_for_context/1)
  end

  defp build_edges_for_context(%{module_name: module_name, outgoing_dependencies: deps}) do
    source_id = sanitize_module_name(module_name)

    deps
    |> Enum.map(fn %{target_component: target} ->
      target_id = sanitize_module_name(target.module_name)
      "#{source_id} --> #{target_id}"
    end)
  end

  defp sanitize_module_name(module_name) do
    module_name
    |> String.replace(".", "_")
    |> String.downcase()
  end
end
