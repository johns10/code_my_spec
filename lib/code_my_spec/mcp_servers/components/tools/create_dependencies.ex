defmodule CodeMySpec.MCPServers.Components.Tools.CreateDependencies do
  @moduledoc """
  Creates multiple dependencies in batch.
  Returns successful creations and any validation errors.
  """

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Components
  alias CodeMySpec.MCPServers.Components.ComponentsMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
    field :dependencies, {:list, :map}, required: true
  end

  @impl true
  def execute(params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame) do
      {successes, failures} =
        params.dependencies
        |> Enum.with_index()
        |> Enum.reduce({[], []}, fn {dependency, index}, {success_acc, failure_acc} ->
          case Components.create_dependency(scope, dependency) do
            {:ok, created_dependency} ->
              {[created_dependency | success_acc], failure_acc}

            {:error, changeset} ->
              {success_acc, [{index, changeset} | failure_acc]}
          end
        end)

      successes = Enum.reverse(successes)
      failures = Enum.reverse(failures)

      case failures do
        [] ->
          {:reply, ComponentsMapper.dependencies_batch_response(successes), frame}

        _has_failures ->
          {:reply, ComponentsMapper.batch_errors_response(successes, failures), frame}
      end
    else
      {:error, reason} ->
        {:reply, ComponentsMapper.error(reason), frame}
    end
  end
end