defmodule CodeMySpec.ComponentCodingSessions.Steps.GenerateTests do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.{Rules, Agents, Utils}
  alias CodeMySpec.Sessions.Session

  def get_command(
        scope,
        %Session{project: project, component: component, state: state},
        _opts \\ []
      ) do
    with {:ok, component_design} <- get_component_design(state),
         {:ok, rules} <- get_test_rules(scope, component),
         {:ok, prompt} <-
           build_test_generation_prompt(project, component, component_design, rules),
         {:ok, agent} <- Agents.create_agent(:unit_coder, "test-generator", :claude_code),
         {:ok, command} <- Agents.build_command(agent, prompt) do
      [command_string, pipe] = command
      {:ok, Command.new(__MODULE__, command_string, pipe)}
    end
  end

  def handle_result(_scope, session, result, _opts \\ []) do
    test_file_paths = extract_test_file_paths(session)
    state_updates = %{"test_files" => test_file_paths}
    {:ok, state_updates, result}
  end

  defp get_component_design(%{"component_design" => design}) when is_binary(design),
    do: {:ok, design}

  defp get_component_design(_state),
    do: {:error, "Component design not found in session state"}

  defp get_test_rules(scope, component) do
    component_type = component.type

    scope
    |> Rules.find_matching_rules(Atom.to_string(component_type), "code")
    |> case do
      rules when is_list(rules) -> {:ok, rules}
      error -> error
    end
  end

  defp build_test_generation_prompt(project, component, component_design, rules) do
    rules_text = Enum.map_join(rules, "\n\n", & &1.content)
    %{test_file: test_file_path} = Utils.component_files(component, project)

    prompt =
      """
      Generate comprehensive test files for a Phoenix component following TDD principles.

      Project: #{project.name}
      Component Name: #{component.name}
      Type: #{component.type}

      Component Design:
      #{component_design}

      Test Generation Instructions:
      1. Investigate all fixtures in test/support/fixtures/
      2. Identify which existing fixtures are useful for this component
      3. Read those useful fixture files
      4. Determine what new fixtures are needed based on the component design
      5. Generate new fixture files following observed patterns
      6. Write comprehensive test files that leverage the fixtures
      7. Follow TDD principles to define the component's contract
      8. Cover all public API functions specified in the component design
      9. Write concise, obvious, easy to read tests

      Coding Rules:
      #{rules_text}

      Write the test file to #{test_file_path}
      """

    {:ok, prompt}
  end

  defp extract_test_file_paths(%Session{project: project, component: component}) do
    %{test_file: test_file_path} = Utils.component_files(component, project)
    [test_file_path]
  end
end
