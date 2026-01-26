defmodule CodeMySpec.McpServers.Architecture.Tools.ListSpecs do
  @moduledoc "Lists all component specs in the project"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Components
  alias CodeMySpec.Components.ComponentRepository
  alias CodeMySpec.McpServers.Architecture.ArchitectureMapper
  alias CodeMySpec.McpServers.Validators

  schema do
    field :type, :string
  end

  @impl true
  def execute(params, frame) do
    with {:ok, scope} <- Validators.validate_project_scope(frame),
         {:ok, components} <- list_components(scope, params) do
      {:reply, ArchitectureMapper.specs_list_response(components), frame}
    else
      {:error, reason} ->
        {:reply, ArchitectureMapper.error(reason), frame}
    end
  end

  defp list_components(scope, params) do
    components =
      if Map.has_key?(params, :type) and not is_nil(params.type) do
        ComponentRepository.list_components_by_type(scope, params.type)
      else
        Components.list_components(scope)
      end

    {:ok, components}
  end
end
