defmodule CodeMySpec.McpServers.Architecture.ArchitectureMapper do
  alias Hermes.Server.Response
  alias CodeMySpec.McpServers.Formatters

  def spec_created(component, spec_path) do
    Response.tool()
    |> Response.json(%{
      success: true,
      message: "Spec file created successfully",
      component: component_summary(component),
      spec_path: spec_path
    })
  end

  def spec_updated(component, spec_path) do
    Response.tool()
    |> Response.json(%{
      success: true,
      message: "Spec metadata updated successfully",
      component: component_summary(component),
      spec_path: spec_path
    })
  end

  def spec_response(component, spec_path, spec_content) do
    Response.tool()
    |> Response.json(%{
      component: component_detail(component),
      spec_path: spec_path,
      spec_content: spec_content
    })
  end

  def specs_list_response(components) do
    Response.tool()
    |> Response.json(%{
      specs: Enum.map(components, &spec_summary/1)
    })
  end

  def architecture_summary_response(summary) do
    Response.tool()
    |> Response.json(summary)
  end

  def component_impact_response(impact) do
    Response.tool()
    |> Response.json(%{
      component: component_summary(impact.component),
      direct_dependents: Enum.map(impact.direct_dependents, &component_summary/1),
      transitive_dependents: Enum.map(impact.transitive_dependents, &component_summary/1),
      affected_contexts: Enum.map(impact.affected_contexts, &component_summary/1)
    })
  end

  def component_view_response(markdown) do
    Response.tool()
    |> Response.text(markdown)
  end

  def validation_result_response(:ok) do
    Response.tool()
    |> Response.json(%{
      valid: true,
      message: "No circular dependencies detected"
    })
  end

  def validation_result_response({:error, cycles}) do
    formatted_cycles =
      Enum.map(cycles, fn cycle ->
        %{
          path: cycle.path,
          components:
            Enum.map(cycle.components, fn comp ->
              %{
                id: comp.id,
                name: comp.name,
                type: comp.type,
                module_name: comp.module_name
              }
            end)
        }
      end)

    Response.tool()
    |> Response.json(%{
      valid: false,
      message: "Circular dependencies detected",
      cycles: formatted_cycles
    })
  end

  def prompt_response(prompt) do
    Response.tool()
    |> Response.text(prompt)
  end

  def validation_error(changeset) do
    Response.tool()
    |> Response.error(Formatters.format_changeset_errors(changeset))
  end

  def error(error) when is_atom(error), do: error |> to_string() |> error()

  def error(error) when is_binary(error) do
    Response.tool()
    |> Response.error(error)
  end

  def error(%Ecto.Changeset{} = changeset) do
    validation_error(changeset)
  end

  def not_found_error do
    Response.tool()
    |> Response.error("Resource not found")
  end

  defp component_summary(component) do
    %{
      id: component.id,
      name: component.name,
      type: component.type,
      module_name: component.module_name,
      description: component.description
    }
  end

  defp component_detail(component) do
    base = component_summary(component)

    dependencies =
      case Map.get(component, :outgoing_dependencies, :not_loaded) do
        %Ecto.Association.NotLoaded{} -> []
        deps when is_list(deps) -> Enum.map(deps, & &1.target_component.module_name)
        _ -> []
      end

    dependents =
      case Map.get(component, :incoming_dependencies, :not_loaded) do
        %Ecto.Association.NotLoaded{} -> []
        deps when is_list(deps) -> Enum.map(deps, & &1.source_component.module_name)
        _ -> []
      end

    Map.merge(base, %{
      dependencies: dependencies,
      dependents: dependents
    })
  end

  defp spec_summary(component) do
    %{
      id: component.id,
      name: component.name,
      type: component.type,
      module_name: component.module_name,
      description: component.description,
      spec_path: build_spec_path(component.module_name)
    }
  end

  defp build_spec_path(module_name) do
    path_parts =
      module_name
      |> String.split(".")
      |> Enum.map(&Macro.underscore/1)

    Path.join(["docs/spec" | path_parts]) <> ".spec.md"
  end
end
