defmodule CodeMySpec.ContextDesignSessions.Steps.ValidateDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour
  require Logger

  alias CodeMySpec.Documents
  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.Sessions
  alias CodeMySpec.Utils

  def get_command(_scope, %{component: component, project: project}, _opts \\ []) do
    %{spec_file: spec_file} = Utils.component_files(component, project)
    {:ok, Command.new(__MODULE__, "read_file", metadata: %{path: spec_file})}
  end

  def handle_result(scope, session, result, _opts \\ []) do
    with {:ok, component_design} <- get_component_design(result),
         {:ok, document} <-
           Documents.create_dynamic_document(component_design, :context_spec),
         {:ok, _created} <- create_components(scope, session, document.sections) do
      {:ok, %{}, result}
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

  defp create_components(scope, session, %{
         "components" => components,
         "dependencies" => dependencies
       })
       when is_list(components) and is_list(dependencies) do
    project_module_name = scope.active_project.module_name
    filtered_deps = filter_project_dependencies(dependencies, project_module_name)

    component_attrs_list =
      Enum.map(components, fn %{module_name: module_name, description: description} ->
        %{
          name: extract_component_name(module_name),
          module_name: module_name,
          description: description,
          parent_component_id: session.component.id,
          type: :other
        }
      end)

    CodeMySpec.Components.create_components_with_dependencies(
      scope,
      component_attrs_list,
      filtered_deps
    )
  end

  defp create_components(_scope, _session, _sections) do
    {:error, "components or dependencies section missing or invalid"}
  end

  defp extract_component_name(module_name) do
    module_name
    |> String.split(".")
    |> List.last()
  end

  defp filter_project_dependencies(dependencies, project_module_name) do
    Enum.filter(dependencies, fn dep ->
      String.starts_with?(dep, project_module_name)
    end)
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
