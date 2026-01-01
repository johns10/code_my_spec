defmodule CodeMySpec.ComponentCodingSessions.Steps.GenerateImplementation do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.{Rules, Utils, Components}
  alias CodeMySpec.Sessions.{Session, Steps.Helpers}

  def get_command(
        scope,
        %Session{project: project, component: component} = session,
        opts \\ []
      ) do
    with {:ok, rules} <- get_implementation_rules(scope, component),
         similar_components <- Components.list_similar_components(scope, component),
         {:ok, prompt} <-
           build_implementation_prompt(project, component, rules, similar_components),
         {:ok, command} <-
           Helpers.build_agent_command(
             __MODULE__,
             session,
             :unit_coder,
             "implementation-generator",
             prompt,
             opts
           ) do
      {:ok, command}
    end
  end

  def handle_result(_scope, _session, result, _opts \\ []) do
    {:ok, %{}, result}
  end

  defp get_implementation_rules(_scope, component) do
    component_type = component.type

    Rules.find_matching_rules(Atom.to_string(component_type), "code")
    |> case do
      rules when is_list(rules) -> {:ok, rules}
    end
  end

  defp build_implementation_prompt(project, component, rules, similar_components) do
    rules_text = Enum.map_join(rules, "\n\n", & &1.content)

    %{
      spec_file: spec_file_path,
      code_file: code_file_path,
      test_file: test_file_path
    } = Utils.component_files(component, project)

    similar_components_text = format_similar_components(project, similar_components)

    prompt =
      """
      Generate the implementation for a Phoenix component.

      Project: #{project.name}
      Project Description: #{project.description}
      Component Name: #{component.name}
      Component Description: #{component.description || "No description provided"}
      Type: #{component.type}

      Design File: #{spec_file_path}
      Test File: #{test_file_path}

      Implementation Instructions:
      1. Read the design file to understand the component architecture
      2. Read the test file to understand the expected behavior and any test fixtures
      3. Create all necessary module files following the component design
      4. Implement all public API functions specified in the design
      5. Ensure the implementation satisfies the tests
      6. Follow project patterns for similar components
      7. Create schemas, migrations, or supporting code as needed

      Similar Components (for implementation pattern inspiration):
      #{similar_components_text}

      Coding Rules:
      #{rules_text}

      Write the implementation to #{code_file_path}
      """

    {:ok, prompt}
  end

  defp format_similar_components(_project, []), do: "No similar components provided"

  defp format_similar_components(project, similar_components) do
    similar_components
    |> Enum.with_index(1)
    |> Enum.map_join("\n\n", fn {component, index} ->
      files = Utils.component_files(component, project)

      """
      #{index}. #{component.name} (#{component.type})
         Description: #{component.description || "No description"}
         Design: #{files.design_file}
         Implementation: #{files.code_file}
         Test: #{files.test_file}
      """
      |> String.trim()
    end)
  end
end
