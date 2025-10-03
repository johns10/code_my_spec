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

    with {:ok, document} <- Documents.create_component_document(result.stdout, :context),
         {:ok, _components} <- create_components(scope, session, document) do
      {:ok, %{}, result}
    else
      {:error, error} ->
        updated_result = update_result_with_error(scope, result, error)
        {:ok, %{state: updated_state}, updated_result}

      error ->
        error
    end
  end

  defp create_components(scope, session, %{components: components, dependencies: dependencies}) do
    project_module_name = scope.active_project.module_name
    filtered_deps = filter_project_dependencies(dependencies, project_module_name)

    created_components =
      Enum.map(components, fn component_ref ->
        type = extract_type_from_table(component_ref.table)

        component_attrs = %{
          name: component_ref.module_name |> String.split(".") |> List.last(),
          module_name: component_ref.module_name,
          description: component_ref.description,
          parent_component_id: session.component.id,
          type: type
        }

        CodeMySpec.Components.upsert_component(scope, component_attrs)
      end)

    create_dependencies(scope, created_components, filtered_deps)
  end

  defp filter_project_dependencies(dependencies, project_module_name) do
    Enum.filter(dependencies, fn dep ->
      String.starts_with?(dep, project_module_name)
    end)
  end

  defp create_dependencies(_scope, components, []), do: {:ok, components}

  defp create_dependencies(scope, components, dependencies) do
    # Create dependency records for filtered project dependencies
    dependencies
    |> Enum.reduce_while(:ok, fn dep, _acc ->
      case CodeMySpec.Components.get_component_by_module_name(scope, dep) do
        # Skip if no matching component found
        nil ->
          {:cont, :ok}

        target_component ->
          dependency_attrs = %{
            # Use first created component as source
            from_component_id: List.first(components).id,
            to_component_id: target_component.id,
            dependency_type: :internal
          }

          case CodeMySpec.Components.create_dependency(scope, dependency_attrs) do
            {:ok, _} -> {:cont, :ok}
            {:error, _} = error -> {:halt, error}
          end
      end
    end)
    |> case do
      :ok -> {:ok, components}
      error -> error
    end
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
