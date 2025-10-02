defmodule CodeMySpec.Utils do
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Projects.Project

  def component_files(
        %Component{module_name: component_module_name},
        %Project{module_name: project_module_name}
      ) do
    component_module_name = String.replace(component_module_name, "#{project_module_name}.", "")
    full_module_name = "#{project_module_name}.#{component_module_name}"
    module_path = module_to_path(full_module_name)

    %{
      design_file: "docs/design/#{module_path}.md",
      code_file: "lib/#{module_path}.ex",
      test_file: "test/#{module_path}_test.exs"
    }
  end

  defp module_to_path(module_name) do
    module_name
    |> String.replace_prefix("", "")
    |> Macro.underscore()
    |> String.replace(".", "/")
    |> String.downcase()
  end

  def changeset_error_to_string(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> flatten_errors()
    |> Enum.map(fn {field, message} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

  defp flatten_errors(errors, prefix \\ nil) do
    Enum.flat_map(errors, fn {field, value} ->
      field_name = if prefix, do: "#{prefix}.#{field}", else: field

      cond do
        is_list(value) and Enum.all?(value, &is_map/1) ->
          # embeds_many: list of maps with errors
          value
          |> Enum.with_index()
          |> Enum.flat_map(fn {item_errors, index} ->
            flatten_errors(item_errors, "#{field_name}[#{index}]")
          end)

        is_list(value) ->
          # list of error messages
          Enum.map(value, fn msg -> {field_name, msg} end)

        is_map(value) ->
          # nested map of errors
          flatten_errors(value, field_name)

        true ->
          [{field_name, value}]
      end
    end)
  end
end
