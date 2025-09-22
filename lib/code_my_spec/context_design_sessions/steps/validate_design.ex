defmodule CodeMySpec.ContextDesignSessions.Steps.ValidateDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Documents
  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.Utils

  def get_command(_scope, %{component: component, project: project}) do
    %{design_file: design_file_path} = Utils.component_files(component, project)
    {:ok, Command.new(__MODULE__, "cat #{design_file_path}")}
  end

  def handle_result(scope, session, interaction) do
    with {:ok, document} <- Documents.create_document(interaction.result.stdout, :context_design),
         {:ok, _components} <- create_components(scope, session, document) do
      {:ok, session}
    else
      error -> error
    end
  end

  defp create_components(scope, session, %{components: components, dependencies: dependencies}) do
    project_module_name = scope.active_project.module_name
    filtered_deps = filter_project_dependencies(dependencies, project_module_name)

    components
    |> Enum.reduce_while([], fn component_ref, acc ->
      type = extract_type_from_table(component_ref.table)

      component_attrs = %{
        name: component_ref.module_name |> String.split(".") |> List.last(),
        module_name: component_ref.module_name,
        description: component_ref.description,
        parent_component_id: session.component.id,
        type: type
      }

      case CodeMySpec.Components.create_component(scope, component_attrs) do
        {:ok, component} -> {:cont, [component | acc]}
        {:error, _changeset} = error -> {:halt, error}
      end
    end)
    |> case do
      {:error, _} = error -> error
      components -> create_dependencies(scope, components, filtered_deps)
    end
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
end
