defmodule CodeMySpec.MCPServers.Components.Tools.CreateDependency do
  @moduledoc "Creates a dependency relationship between components"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Components
  alias CodeMySpec.MCPServers.Components.ComponentsMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
    field :source_component_id, :integer, required: true
    field :target_component_id, :integer, required: true

    field :type, :string,
      required: true,
      enum: [:require, :import, :alias, :use, :call, :other],
      description: "Must be one of require, import, alias, use, call"
  end

  @impl true
  def execute(params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame),
         {:ok, dependency} <- Components.create_dependency(scope, params),
         :ok <- Components.validate_dependency_graph(scope) do
      dependency = Components.get_dependency!(scope, dependency.id)
      {:reply, dependency_response(dependency), frame}
    else
      {:error, changeset = %Ecto.Changeset{}} ->
        {:reply, ComponentsMapper.validation_error(changeset), frame}

      {:error, cycles} when is_list(cycles) ->
        {:reply, circular_dependency_error(cycles), frame}

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
      target_component: component_summary(dependency.target_component)
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

  defp circular_dependency_error(cycles) do
    alias Hermes.Server.Response

    cycle_descriptions =
      Enum.map(cycles, fn cycle ->
        path = Enum.join(cycle.path, " -> ")
        "#{path} -> #{hd(cycle.path)}"
      end)

    error_message = """
    Circular dependency detected. This would create the following cycles:
    #{Enum.join(cycle_descriptions, "\n")}
    """

    Response.tool()
    |> Response.error(error_message)
  end
end
