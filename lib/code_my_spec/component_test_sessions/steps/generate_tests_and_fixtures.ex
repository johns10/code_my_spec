defmodule CodeMySpec.ComponentTestSessions.Steps.GenerateTestsAndFixtures do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.{Rules, Utils, Components, Environments}
  alias CodeMySpec.Sessions.{Session, Steps.Helpers}

  def get_command(
        scope,
        %Session{component: component} = session,
        opts \\ []
      ) do
    with {:ok, test_rules} <- get_test_rules(scope, component),
         {:ok, prompt} <- build_prompt(session, test_rules, Components.list_similar_components(scope, component)) do
      Helpers.build_agent_command(
        __MODULE__,
        session,
        :test_writer,
        "component-test-and-fixture-generator",
        prompt,
        opts
      )
    end
  end

  def handle_result(_scope, _session, result, _opts \\ []) do
    {:ok, %{}, result}
  end

  defp get_test_rules(_scope, component) do
    component_type = component.type

    Rules.find_matching_rules(component_type, "test")
    |> case do
      rules when is_list(rules) -> {:ok, rules}
    end
  end

  defp build_prompt(
         %{project: project, component: component} = session,
         test_rules,
         similar_components
       ) do
    test_rules_text = Enum.map_join(test_rules, "\n\n", & &1.content)
    similar_text = format_similar_components(project, similar_components)

    %{spec_file: spec_file_path, test_file: test_file_path, code_file: code_file_path} =
      Utils.component_files(component, project)

    # Check if implementation exists
    implementation_exists = check_implementation_exists(session, code_file_path)

    tdd_section =
      if implementation_exists do
        """
        The component implementation already exists.
        Write tests that validate the existing implementation against the design specification.
        """
      else
        """
        The component doesn't exist yet.
        You are to write the tests before we implement the module, TDD style.
        Only write the tests defined in the Test Assertions section of the design.
        If you want to write more cases, you must modify the design first.
        """
      end

    parent_spec_file_path =
      if component.parent_component do
        parent_component = component.parent_component
        %{spec_file: parent_spec_file_path} = Utils.component_files(parent_component, project)
        parent_spec_file_path
      else
        "no parent design"
      end

    prompt =
      """
      Generate tests and fixtures for the following Phoenix component.
      #{tdd_section}

      Tests should be grouped by describe blocks that match the function signature EXACTLY.
      Any blocks that don't match the test assertions in the spec will be rejected and you'll have to redo them.

      describe "get_test_assertions/1" do
        test "extracts test names from test blocks", %{tmp_dir: tmp_dir} do
          ...test code
        end
      end

      Project: #{project.name}
      Project Description: #{project.description}
      Component Name: #{component.name}
      Component Type: #{component.type}

      Parent Context Design File: #{parent_spec_file_path}
      Component Design File: #{spec_file_path}

      Similar Components (for test pattern inspiration):
      #{similar_text}

      Test Rules:
      #{test_rules_text}

      Write the test file to #{test_file_path}.

      Focus on:
      - Reading the design files to understand the component architecture and parent context
      - Creating reusable fixture functions for test data
      - Testing all public API functions
      - Testing edge cases and error conditions
      - Testing with valid and invalid data
      - Following test and fixture organization patterns from the rules
      - Only implementing the test assertions from the design file
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
         Design: #{files.spec_file}
         Implementation: #{files.code_file}
         Test: #{files.test_file}
      """
      |> String.trim()
    end)
  end

  defp check_implementation_exists(session, code_file_path) do
    # Create environment to check file existence
    {:ok, environment} = Environments.create(session.environment_type, working_dir: session[:working_dir])
    CodeMySpec.Environments.file_exists?(environment, code_file_path)
  end
end
