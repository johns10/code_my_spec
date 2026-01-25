defmodule CodeMySpec.ComponentSpecSessions.Steps.GenerateComponentSpec do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.{Rules, Utils, Environments}
  alias CodeMySpec.Sessions.{Session, Steps.Helpers}
  alias CodeMySpec.Documents.DocumentSpecProjector
  alias CodeMySpec.Components.Component

  def get_command(scope, %Session{component: component} = session, opts \\ []) do
    with {:ok, rules} <- get_design_rules(scope, component),
         {:ok, prompt} <- build_spec_prompt(session, rules) do
      Helpers.build_agent_command(
        __MODULE__,
        session,
        :component_designer,
        "component-design-generator",
        prompt,
        opts
      )
    end
  end

  def handle_result(_scope, _session, result, _opts \\ []) do
    {:ok, %{}, result}
  end

  defp get_design_rules(_scope, component) do
    component_type = component.type

    Rules.find_matching_rules(component_type, "design")
    |> case do
      rules when is_list(rules) -> {:ok, rules}
    end
  end

  defp build_spec_prompt(session, rules) do
    %{project: project, component: component} = session
    rules_text = Enum.map_join(rules, "\n\n", & &1.content)
    document_spec = DocumentSpecProjector.project_spec(component.type)
    %{spec_file: spec_file_path} = Utils.component_files(component, project)

    parent_component_clause =
      case Map.get(component, :parent_component, nil) do
        %Component{} = parent_component ->
          %{spec_file: parent_spec_file_path} =
            Utils.component_files(parent_component, project)

          "Parent Context Design File: #{parent_spec_file_path}"

        _ ->
          ""
      end

    {:ok, environment} = Environments.create(session.environment_type, working_dir: session[:working_dir])

    %{code_file: code_file, test_file: test_file} =
      Utils.component_files(component, project)

    existing_implementation_clause =
      if Environments.file_exists?(environment, code_file) do
        "Existing Implementation: #{code_file}."
      else
        "The implementation doesn't exist yet."
      end

    existing_test_clause =
      if Environments.file_exists?(environment, test_file) do
        "Existing tests: #{test_file}"
      else
        "The tests don't exist yet."
      end

    prompt =
      """
      Generate a Phoenix component spec for the following.
      Project: #{project.name}
      Project Description: #{project.description}
      Component Name: #{component.name}
      Component Description: #{component.description || "No description provided"}
      Type: #{component.type}
      #{parent_component_clause}
      #{existing_implementation_clause}
      #{existing_test_clause}

      Design Rules:
      #{rules_text}

      Document Specifications:
      #{document_spec}

      Write the document to #{spec_file_path}.
      """

    {:ok, prompt}
  end
end
