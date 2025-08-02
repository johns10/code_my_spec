defmodule CodeMySpec.MCPServers.Components.Tools.DeleteComponent do
  @moduledoc "Deletes a component"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Components
  alias CodeMySpec.MCPServers.Components.ComponentsMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
    field :id, :integer, required: true
  end

  @impl true
  def execute(params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame),
         component <- Components.get_component!(scope, params.id),
         {:ok, component} <- Components.delete_component(scope, component) do
      {:reply, ComponentsMapper.component_response(component), frame}
    else
      {:error, changeset = %Ecto.Changeset{}} ->
        {:reply, ComponentsMapper.validation_error(changeset), frame}

      {:error, atom} ->
        {:reply, ComponentsMapper.error(atom), frame}
    end
  rescue
    Ecto.NoResultsError ->
      {:reply, ComponentsMapper.not_found_error(), frame}
  end
end
