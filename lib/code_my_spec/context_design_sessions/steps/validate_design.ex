defmodule CodeMySpec.ContextDesignSessions.Steps.ValidateDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour
  require Logger

  alias CodeMySpec.Documents
  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.Sessions
  alias CodeMySpec.Utils

  def get_command(_scope, %{component: component, project: project}, _opts \\ []) do
    %{design_file: design_file_path} = Utils.component_files(component, project)
    {:ok, Command.new(__MODULE__, "cat #{design_file_path}")}
  end

  def handle_result(scope, session, result, _opts \\ []) do
    updated_state = Map.put(session.state || %{}, "component_design", result.stdout)

    with {:ok, document} <- Documents.create_context_document(result.stdout),
         {:ok, _components} <- create_components(scope, session, document) do
      {:ok, %{}, result}
    else
      {:error, error} ->
        updated_result = update_result_with_error(scope, result, error)
        {:ok, %{state: updated_state}, updated_result}
    end
  end

  defp create_components(scope, session, %{components: components, dependencies: dependencies}) do
    project_module_name = scope.active_project.module_name
    filtered_deps = filter_project_dependencies(dependencies, project_module_name)

    component_attrs_list =
      Enum.map(components, fn component_ref ->
        type = extract_type_from_table(component_ref.table)

        %{
          name: component_ref.module_name |> String.split(".") |> List.last(),
          module_name: component_ref.module_name,
          description: component_ref.description,
          parent_component_id: session.component.id,
          type: type
        }
      end)

    CodeMySpec.Components.create_components_with_dependencies(
      scope,
      component_attrs_list,
      filtered_deps
    )
  end

  defp filter_project_dependencies(dependencies, project_module_name) do
    Enum.filter(dependencies, fn dep ->
      String.starts_with?(dep, project_module_name)
    end)
  end

  defp extract_type_from_table(table) do
    case table do
      %{"value" => type_value} when is_binary(type_value) ->
        type_value
        |> String.trim()
        |> String.downcase()
        |> String.to_atom()

      %{"type" => type_value} when is_binary(type_value) ->
        # Legacy support for direct type field
        type_value
        |> String.trim()
        |> String.downcase()
        |> String.to_atom()

      _ ->
        :other
    end
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
