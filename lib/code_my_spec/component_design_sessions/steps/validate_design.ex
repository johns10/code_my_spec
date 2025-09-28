defmodule CodeMySpec.ComponentDesignSessions.Steps.ValidateDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.{Documents, Sessions}
  alias CodeMySpec.Sessions.{Command, Result}

  def get_command(_scope, %{component: component, project: project}) do
    %{design_file: design_file_path} = CodeMySpec.Utils.component_files(component, project)
    {:ok, Command.new(__MODULE__, "cat #{design_file_path}")}
  end

  def handle_result(scope, session, interaction) do
    with {:ok, component_design} <- get_component_design(interaction),
         updated_state <- Map.put(session.state || %{}, :component_design, component_design),
         {:ok, updated_session} <-
           Sessions.update_session(scope, session, %{state: updated_state}),
         document_type <- determine_document_type(session.component),
         {:ok, _document} <- Documents.create_document(component_design, document_type, scope) do
      {:ok, updated_session}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        error_message = format_changeset_errors(changeset)

        error_result =
          Result.error_attrs("Component design validation failed", stderr: error_message)

        Sessions.update_result(scope, session, interaction.id, error_result)

      {:error, reason} ->
        error_result =
          Result.error_attrs("Component design validation failed: #{inspect(reason)}")

        Sessions.update_result(scope, session, interaction.id, error_result)
    end
  end

  defp get_component_design(%{result: %{stdout: component_design}})
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
