defmodule CodeMySpec.ComponentCodingSessions.Steps.GenerateImplementation do
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
         {:ok, rules} <- get_implementation_rules(scope, component),
         {:ok, prompt} <-
           build_implementation_prompt(project, component, component_design, rules),
         {:ok, agent} <-
           Agents.create_agent(:context_designer, "implementation-generator", :claude_code),
         {:ok, command} <- Agents.build_command(agent, prompt) do
      [command_string, pipe] = command
      {:ok, Command.new(__MODULE__, command_string, pipe)}
    end
  end

  def handle_result(_scope, _session, result, _opts \\ []) do
    {:ok, %{}, result}
  end

  defp get_component_design(%{"component_design" => design}) when is_binary(design),
    do: {:ok, design}

  defp get_component_design(_state),
    do: {:error, "Component design not found in session state"}

  defp get_implementation_rules(scope, component) do
    component_type = component.type

    scope
    |> Rules.find_matching_rules(Atom.to_string(component_type), "code")
    |> case do
      rules when is_list(rules) -> {:ok, rules}
      error -> error
    end
  end

  defp build_implementation_prompt(project, component, component_design, rules) do
    rules_text = Enum.map_join(rules, "\n\n", & &1.content)

    %{code_file: code_file_path, test_file: test_file_path} =
      Utils.component_files(component, project)

    prompt =
      """
      Generate the implementation for a Phoenix component to satisfy the tests written in the previous step.

      Project: #{project.name}
      Project Description: #{project.description}
      Component Name: #{component.name}
      Component Description: #{component.description || "No description provided"}
      Type: #{component.type}

      Component Design:
      #{component_design}

      Implementation Instructions:
      1. Read the test file to understand the expected behavior
      2. Create all necessary module files following the component design
      3. Implement all public API functions specified in the design
      4. Ensure the implementation satisfies the tests
      5. Follow project patterns for similar components
      6. Create schemas, migrations, or supporting code as needed

      Coding Rules:
      #{rules_text}

      Test File Path:
      #{test_file_path}

      Write the implementation to #{code_file_path}
      """

    {:ok, prompt}
  end
end
