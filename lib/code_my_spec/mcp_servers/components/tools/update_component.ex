defmodule CodeMySpec.MCPServers.Components.Tools.UpdateComponent do
  @moduledoc """
  Updates a component.
  Include all fields in the input that you want to update.
  They will be persisted exactly as you send them.
  """

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Components
  alias CodeMySpec.MCPServers.Components.ComponentsMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
    field :id, :string, required: true
    field :name, :string

    field :type, :enum,
      enum: [:context, :coordination_context],
      description:
        "Must be one of: context (domain contexts that own entities), :coordination_context (orchestrate workflows across domain context)"

    field :module_name, :string
    field :description, :string
  end

  @impl true
  def execute(params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame),
         {:ok, id} <- parse_id(params.id),
         {:ok, component} <- find_component(scope, id),
         {:ok, component} <-
           Components.update_component(scope, component, Map.drop(params, [:id])) do
      {:reply, ComponentsMapper.component_response(component), frame}
    else
      {:error, changeset = %Ecto.Changeset{}} ->
        {:reply, ComponentsMapper.validation_error(changeset), frame}

      {:error, :not_found} ->
        {:reply, ComponentsMapper.not_found_error(), frame}

      {:error, atom} ->
        {:reply, ComponentsMapper.error(atom), frame}
    end
  end

  defp find_component(scope, id) do
    case Components.get_component(scope, id) do
      nil -> {:error, :not_found}
      component -> {:ok, component}
    end
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} -> {:ok, int_id}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_id(_), do: {:error, :invalid_id}
end
