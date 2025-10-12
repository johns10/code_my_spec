defmodule CodeMySpec.ComponentTestSessions.Steps.GenerateTestsAndFixtures do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.{Rules, Utils}
  alias CodeMySpec.Sessions.{Session, Steps.Helpers}

  def get_command(
        scope,
        %Session{project: project, component: component},
        opts \\ []
      ) do
    with {:ok, test_rules} <- get_test_rules(scope, component),
         {:ok, prompt} <- build_prompt(project, component, test_rules),
         {:ok, command} <-
           Helpers.build_agent_command(
             __MODULE__,
             :test_writer,
             "component-test-and-fixture-generator",
             prompt,
             opts
           ) do
      {:ok, command}
    end
  end

  def handle_result(_scope, _session, result, _opts \\ []) do
    {:ok, %{}, result}
  end

  defp get_test_rules(scope, component) do
    component_type = component.type

    scope
    |> Rules.find_matching_rules(Atom.to_string(component_type), "test")
    |> case do
      rules when is_list(rules) -> {:ok, rules}
      error -> error
    end
  end

  defp build_prompt(project, component, test_rules) do
    test_rules_text = Enum.map_join(test_rules, "\n\n", & &1.content)

    %{design_file: design_file_path, test_file: test_file_path} =
      Utils.component_files(component, project)

    parent_design_file_path =
      if component.parent_component do
        parent_component = component.parent_component
        %{design_file: parent_design_file_path} = Utils.component_files(parent_component, project)
        parent_design_file_path
      else
        "no parent design"
      end

    prompt =
      """
      Generate comprehensive tests and fixtures for the following Phoenix component.
      The component doesn't exist yet.
      You are to write the tests before we implement the module, TDD style.

      Project: #{project.name}
      Project Description: #{project.description}
      Component Name: #{component.name}
      Component Type: #{component.type}

      Parent Context Design File: #{parent_design_file_path}
      Component Design File: #{design_file_path}

      Test Rules:
      #{test_rules_text}

      Write the test file to #{test_file_path}.

      Focus on:
      - Reading the design files to understand the component architecture and parent context
      - Creating reusable fixture functions for test data
      - Testing all public API functions
      - Testing edge cases and error conditions
      - Testing with valid and invalid data
      - Testing proper scoping and access patterns
      - Following test and fixture organization patterns from the rules
      """

    {:ok, prompt}
  end
end
