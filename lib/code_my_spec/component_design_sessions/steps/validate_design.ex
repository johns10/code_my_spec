defmodule CodeMySpec.ComponentDesignSessions.Steps.ValidateDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.{Documents, Sessions}
  alias CodeMySpec.Sessions.{Command}
  require Logger

  def get_command(_scope, %{component: component, project: project}, _opts \\ []) do
    %{design_file: design_file_path} = CodeMySpec.Utils.component_files(component, project)
    {:ok, Command.new(__MODULE__, "cat #{design_file_path}")}
  end

  def handle_result(scope, session, result, _opts \\ []) do
    case get_component_design(result) do
      {:ok, component_design} ->
        updated_state = Map.put(session.state || %{}, "component_design", component_design)

        case create_document(component_design, session.component) do
          {:ok, _document} ->
            {:ok, %{state: updated_state}, result}

          {:error, error} ->
            updated_result = update_result_with_error(scope, result, error)
            {:ok, %{state: updated_state}, updated_result}
        end

      {:error, reason} ->
        error = "Component design validation failed: #{inspect(reason)}"
        updated_result = update_result_with_error(scope, result, error)
        {:ok, %{}, updated_result}
    end
  end

  defp get_component_design(%{stdout: component_design})
       when is_binary(component_design) do
    if String.trim(component_design) == "" do
      {:error, "component design is empty"}
    else
      {:ok, component_design}
    end
  end

  defp get_component_design(_state) do
    {:error, "component_design not found in last interaction"}
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

  defp format_error(error) when is_binary(error), do: error
end
