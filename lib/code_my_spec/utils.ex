defmodule CodeMySpec.Utils do
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Projects.Project

  def component_files(
        %Component{module_name: component_module_name},
        %Project{module_name: project_module_name}
      ) do
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
end
