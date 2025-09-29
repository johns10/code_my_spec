defmodule CodeMySpec.ComponentDesignSessions.Steps.ValidateDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.{Documents, Sessions}
  alias CodeMySpec.Sessions.{Command}
  require Logger

  def get_command(_scope, %{component: component, project: project}) do
    %{design_file: design_file_path} = CodeMySpec.Utils.component_files(component, project)
    {:ok, Command.new(__MODULE__, "cat #{design_file_path}")}
  end

  def handle_result(scope, session, result) do
    with {:ok, component_design} <- get_component_design(result),
         updated_state <- Map.put(session.state || %{}, :component_design, component_design),
         document_type <- determine_document_type(session.component),
         {:ok, _document} <- Documents.create_document(component_design, document_type, scope) do
      {:ok, %{state: updated_state}, result}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        error_message = format_changeset_errors(changeset)

        attrs = %{
          status: :error,
          error_message: error_message
        }

        case Sessions.update_result(scope, result, attrs) do
          {:ok, updated_result} ->
            {:ok, %{}, updated_result}

          {:error, changeset} ->
            Logger.error("#{__MODULE__} failed to update result", changeset: changeset)
            {:ok, %{}, result}
        end

      {:error, reason} ->
        error_message = "Component design validation failed: #{inspect(reason)}"

        attrs = %{
          status: :error,
          error_message: error_message
        }

        case Sessions.update_result(scope, result, attrs) do
          {:ok, updated_result} ->
            {:ok, %{}, updated_result}

          {:error, changeset} ->
            Logger.error("#{__MODULE__} failed to update result", changeset: changeset)
            {:ok, %{}, result}
        end
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

  defp determine_document_type(component) do
    case component.type do
      :context -> :context_design
      :coordination_context -> :context_design
      _ -> :component_design
    end
  end

  defp format_changeset_errors(%Ecto.Changeset{errors: errors}) do
    errors
    |> Enum.map(fn {field, {message, _opts}} ->
      "#{field}: #{message}"
    end)
    |> Enum.join(", ")
  end
end
