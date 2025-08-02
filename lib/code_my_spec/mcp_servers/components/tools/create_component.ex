defmodule CodeMySpec.MCPServers.Components.Tools.CreateComponent do
  @moduledoc "Creates a component"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Components
  alias CodeMySpec.MCPServers.Components.ComponentsMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
    field :name, :string, required: true

    field :type, :string,
      required: true,
      enum: [:context, :coordination_context],
      description:
        "Must be one of: context (domain contexts that own entities), :coordination_context (orchestrate workflows across domain context)"

    field :module_name, :string, required: true
    field :description, :string, required: false
  end

  @impl true
  @spec execute(any(), any()) :: {:reply, Hermes.Server.Response.t(), any()}
  def execute(params, frame) do
    IO.puts("In create component")
    IO.inspect(params)

    with {:ok, scope} <- Validators.validate_scope(frame),
         {:ok, component} <- Components.create_component(scope, params) do
      {:reply, ComponentsMapper.component_response(component), frame}
    else
      {:error, changeset = %Ecto.Changeset{}} ->
        {:reply, ComponentsMapper.validation_error(changeset), frame}

      {:error, atom} ->
        {:reply, ComponentsMapper.error(atom), frame}
    end
  end
end
