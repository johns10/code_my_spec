defmodule CodeMySpec.MCPServers.Components.Tools.CreateComponents do
  @moduledoc """
  Creates multiple components in batch.
  Returns successful creations and any validation errors.
  """

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Components
  alias CodeMySpec.MCPServers.Components.ComponentsMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
    field :components, {:list, :map}, required: true
  end

  @impl true
  def execute(params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame) do
      {successes, failures} =
        params.components
        |> Enum.with_index()
        |> Enum.reduce({[], []}, fn {component, index}, {success_acc, failure_acc} ->
          case Components.create_component(scope, component) do
            {:ok, created_component} ->
              {[created_component | success_acc], failure_acc}

            {:error, changeset} ->
              {success_acc, [{index, changeset} | failure_acc]}
          end
        end)

      successes = Enum.reverse(successes)
      failures = Enum.reverse(failures)

      case failures do
        [] ->
          {:reply, ComponentsMapper.components_batch_response(successes), frame}

        _has_failures ->
          {:reply, ComponentsMapper.batch_errors_response(successes, failures), frame}
      end
    else
      {:error, reason} ->
        {:reply, ComponentsMapper.error(reason), frame}
    end
  end
end