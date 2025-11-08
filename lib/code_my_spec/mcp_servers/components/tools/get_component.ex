defmodule CodeMySpec.MCPServers.Components.Tools.GetComponent do
  @moduledoc "Gets a single component by ID"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Components
  alias CodeMySpec.MCPServers.Components.ComponentsMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
    field :component_id, :string, required: true
  end

  @impl true
  def execute(params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame),
         component <- Components.get_component!(scope, params.component_id),
         component <- load_similar_components(scope, component) do
      {:reply, ComponentsMapper.component_response(component), frame}
    else
      {:error, atom} ->
        {:reply, ComponentsMapper.error(atom), frame}
    end
  end

  defp load_similar_components(scope, component) do
    similar = Components.list_similar_components(scope, component)
    %{component | similar_components: similar}
  end
end
