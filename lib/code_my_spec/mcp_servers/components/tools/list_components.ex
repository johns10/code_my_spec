defmodule CodeMySpec.MCPServers.Components.Tools.ListComponents do
  @moduledoc "Lists all components in a project"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Components
  alias CodeMySpec.MCPServers.Components.ComponentsMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
  end

  @impl true
  def execute(_params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame) do
      components = Components.list_components(scope)
      {:reply, ComponentsMapper.components_list_response(components), frame}
    else
      {:error, atom} ->
        {:reply, ComponentsMapper.error(atom), frame}
    end
  end
end