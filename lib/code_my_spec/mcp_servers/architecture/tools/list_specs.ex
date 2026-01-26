defmodule CodeMySpec.McpServers.Architecture.Tools.ListSpecs do
  @moduledoc """
  Lists component specs in the project with filtering and pagination.

  Use `type` to filter by component type (context, schema, module, etc.).
  Use `contexts_only: true` to get only bounded contexts (the main entry points).
  Use `limit` and `offset` for pagination (defaults: limit=50, offset=0).
  """

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Components
  alias CodeMySpec.Components.ComponentRepository
  alias CodeMySpec.McpServers.Architecture.ArchitectureMapper
  alias CodeMySpec.McpServers.Validators

  @default_limit 50

  schema do
    field :type, :string
    field :contexts_only, :boolean
    field :limit, :integer
    field :offset, :integer
  end

  @impl true
  def execute(params, frame) do
    with {:ok, scope} <- Validators.validate_project_scope(frame),
         {:ok, result} <- list_components(scope, params) do
      {:reply, ArchitectureMapper.specs_list_paginated_response(result), frame}
    else
      {:error, reason} ->
        {:reply, ArchitectureMapper.error(reason), frame}
    end
  end

  defp list_components(scope, params) do
    limit = Map.get(params, :limit) || @default_limit
    offset = Map.get(params, :offset) || 0

    all_components =
      cond do
        Map.get(params, :contexts_only) == true ->
          Components.list_contexts(scope)

        Map.has_key?(params, :type) and not is_nil(params.type) ->
          ComponentRepository.list_components_by_type(scope, params.type)

        true ->
          Components.list_components(scope)
      end

    total = length(all_components)

    paginated =
      all_components
      |> Enum.sort_by(& &1.module_name)
      |> Enum.drop(offset)
      |> Enum.take(limit)

    {:ok,
     %{
       specs: paginated,
       total: total,
       limit: limit,
       offset: offset,
       has_more: offset + limit < total
     }}
  end
end
