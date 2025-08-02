defmodule CodeMySpec.MCPServers.Components.Tools.ShowArchitecture do
  @moduledoc "Shows the complete architecture dependency graph starting from components with stories"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Components
  alias CodeMySpec.MCPServers.Components.ComponentsMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
  end

  @impl true
  def execute(_params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame) do
      architecture = Components.show_architecture(scope)
      {:reply, architecture_response(architecture), frame}
    else
      {:error, atom} ->
        {:reply, ComponentsMapper.error(atom), frame}
    end
  end

  defp architecture_response(architecture) do
    Hermes.Server.Response.tool()
    |> Hermes.Server.Response.json(%{
      architecture: Enum.map(architecture, &architecture_entry/1)
    })
  end

  defp architecture_entry(%{component: component, depth: depth}) do
    %{
      component: component_summary(component),
      depth: depth
    }
  end

  defp component_summary(component) do
    %{
      id: component.id,
      name: component.name,
      type: component.type,
      module_name: component.module_name,
      description: component.description,
      stories_count: length(component.stories || []),
      dependencies_count: length(component.outgoing_dependencies || [])
    }
  end
end
