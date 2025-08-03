defmodule CodeMySpec.MCPServers.Components.Tools.OrphanedContexts do
  @moduledoc "Lists all contexts with no user story and no dependencies"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Components
  alias CodeMySpec.MCPServers.Components.ComponentsMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
  end

  @impl true
  def execute(_params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame) do
      orphaned_contexts = Components.list_orphaned_contexts(scope)
      {:reply, ComponentsMapper.components_list_response(orphaned_contexts), frame}
    else
      {:error, atom} ->
        {:reply, ComponentsMapper.error(atom), frame}
    end
  end
end
