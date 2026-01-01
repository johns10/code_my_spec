defmodule CodeMySpec.ComponentSpecSessions.Steps.ValidateSpec do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.{Documents, Utils}
  alias CodeMySpec.Sessions.Command

  def get_command(_scope, %{component: component, project: project}, _opts \\ []) do
    %{spec_file: path} = Utils.component_files(component, project)
    {:ok, Command.new(__MODULE__, "read_file", metadata: %{path: path})}
  end

  def handle_result(_scope, session, result, _opts \\ []) do
    with {:ok, component_design} <- get_component_design(result),
         {:ok, _document} <- validate_document(component_design, session.component) do
      {:ok, %{}, Map.put(result, :status, :ok)}
    else
      {:error, error} ->
        updated_result =
          result
          |> Map.put(:status, :error)
          |> Map.put(:error_message, error)

        {:ok, %{}, updated_result}
    end
  end

  defp get_component_design(%{data: %{content: content}}) when is_binary(content) do
    if String.trim(content) == "" do
      {:error, "component design is empty"}
    else
      {:ok, content}
    end
  end

  defp get_component_design(_result) do
    {:error, "component_design not found in result"}
  end

  defp validate_document(component_design, component) do
    Documents.create_dynamic_document(component_design, component.type)
  end
end
