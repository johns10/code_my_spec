defmodule CodeMySpec.MCPServers.Components.Tools.DeleteDependency do
  @moduledoc "Deletes a dependency relationship between components"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Components
  alias CodeMySpec.MCPServers.Components.ComponentsMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
    field :id, :string, required: true
  end

  @impl true
  def execute(params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame),
         dependency <- Components.get_dependency!(scope, params.id),
         {:ok, dependency} <- Components.delete_dependency(scope, dependency) do
      {:reply, dependency_response(dependency), frame}
    else
      {:error, changeset = %Ecto.Changeset{}} ->
        {:reply, ComponentsMapper.validation_error(changeset), frame}

      {:error, atom} ->
        {:reply, ComponentsMapper.error(atom), frame}
    end
  end

  defp dependency_response(dependency) do
    alias Hermes.Server.Response

    Response.tool()
    |> Response.json(%{
      id: dependency.id,
      type: dependency.type,
      source_component: component_summary(dependency.source_component),
      target_component: component_summary(dependency.target_component),
      deleted: true
    })
  end

  defp component_summary(component) do
    %{
      id: component.id,
      name: component.name,
      type: component.type,
      module_name: component.module_name
    }
  end
end
