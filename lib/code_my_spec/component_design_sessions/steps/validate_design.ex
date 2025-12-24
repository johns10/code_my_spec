defmodule CodeMySpec.ComponentDesignSessions.Steps.ValidateSpec do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.{Documents, Sessions, Utils}
  alias CodeMySpec.Sessions.{Command}
  require Logger

  def get_command(_scope, %{component: component, project: project}, _opts \\ []) do
    %{spec_file: path} = Utils.component_files(component, project)
    {:ok, Command.new(__MODULE__, "read_file", metadata: %{path: path})}
  end

  def handle_result(scope, session, result, _opts \\ []) do
    with {:ok, component_design} <- get_component_design(result),
         updated_state = Map.put(session.state || %{}, "component_design", component_design),
         {:ok, _document} <- create_document(component_design, session.component) do
      {:ok, %{state: updated_state}, result}
    else
      {:error, error} ->
        updated_result = update_result_with_error(scope, result, error)
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

  defp create_document(component_design, component) do
    Documents.create_dynamic_document(component_design, component.type)
  end

  defp update_result_with_error(scope, result, error) do
    error_message = format_error(error)
    attrs = %{status: :error, error_message: error_message}

    case Sessions.update_result(scope, result, attrs) do
      {:ok, updated_result} ->
        updated_result

      {:error, changeset} ->
        Logger.error("#{__MODULE__} failed to update result", changeset: changeset)
        result
    end
  end

  defp format_error(%Ecto.Changeset{} = changeset) do
    Utils.changeset_error_to_string(changeset)
  end

  defp format_error(error) when is_binary(error), do: error
end
