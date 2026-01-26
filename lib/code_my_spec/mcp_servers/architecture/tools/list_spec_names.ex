defmodule CodeMySpec.McpServers.Architecture.Tools.ListSpecNames do
  @moduledoc """
  Lists spec names in a project (lightweight).

  Returns just module_name, name, and type - no descriptions or paths.
  Use this for quick lookups, selection lists, or when you need to find a component.
  Use `get_spec` to get full details for a specific component.
  """

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Components
  alias CodeMySpec.Components.ComponentRepository
  alias CodeMySpec.McpServers.Architecture.ArchitectureMapper
  alias CodeMySpec.McpServers.Validators

  schema do
    field :type, :string, doc: "Filter by component type (context, schema, module, etc.)"
    field :search, :string, doc: "Filter by module name (case-insensitive contains)"
    field :contexts_only, :boolean, doc: "Return only bounded contexts"
  end

  @impl true
  def execute(params, frame) do
    with {:ok, scope} <- Validators.validate_project_scope(frame) do
      names = list_component_names(scope, params)
      {:reply, ArchitectureMapper.spec_names_response(names), frame}
    else
      {:error, reason} ->
        {:reply, ArchitectureMapper.error(reason), frame}
    end
  end

  defp list_component_names(scope, params) do
    components =
      cond do
        Map.get(params, :contexts_only) == true ->
          Components.list_contexts(scope)

        Map.has_key?(params, :type) and not is_nil(params.type) ->
          ComponentRepository.list_components_by_type(scope, params.type)

        true ->
          Components.list_components(scope)
      end

    components
    |> maybe_filter_by_search(params[:search])
    |> Enum.sort_by(& &1.module_name)
    |> Enum.map(fn comp ->
      %{
        module_name: comp.module_name,
        name: comp.name,
        type: comp.type
      }
    end)
  end

  defp maybe_filter_by_search(components, nil), do: components
  defp maybe_filter_by_search(components, ""), do: components

  defp maybe_filter_by_search(components, search) do
    search_lower = String.downcase(search)

    Enum.filter(components, fn comp ->
      String.contains?(String.downcase(comp.module_name), search_lower)
    end)
  end
end
