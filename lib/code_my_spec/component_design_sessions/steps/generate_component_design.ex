defmodule CodeMySpec.ComponentDesignSessions.Steps.GenerateComponentDesign do
  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.{Rules, Utils}
  alias CodeMySpec.Sessions.{Session, Steps.Helpers}
  alias CodeMySpec.Documents.DocumentSpecProjector

  def get_command(
        scope,
        %Session{project: project, component: component, state: state} = session,
        opts \\ []
      ) do
    with {:ok, rules} <- get_design_rules(scope, component),
         {:ok, prompt} <- build_design_prompt(project, component, rules, state),
         {:ok, command} <-
           Helpers.build_agent_command(
             __MODULE__,
             session,
             :component_designer,
             "component-design-generator",
             prompt,
             opts
           ) do
      {:ok, command}
    end
  end

  def handle_result(_scope, _session, result, _opts \\ []) do
    {:ok, %{}, result}
  end

  defp get_design_rules(_scope, component) do
    component_type = component.type

    Rules.find_matching_rules(Atom.to_string(component_type), "design")
    |> case do
      rules when is_list(rules) -> {:ok, rules}
      error -> error
    end
  end

  defp build_design_prompt(project, component, rules, _state) do
    rules_text = Enum.map_join(rules, "\n\n", & &1.content)
    document_spec = DocumentSpecProjector.project_spec(component.type)
    %{design_file: design_file_path} = Utils.component_files(component, project)

    parent_component = component.parent_component
    %{design_file: parent_design_file_path} = Utils.component_files(parent_component, project)

    prompt =
      """
      Generate a Phoenix component design for the following.

      Project: #{project.name}
      Project Description: #{project.description}
      Component Name: #{component.name}
      Component Description: #{component.description || "No description provided"}
      Type: #{component.type}

      Parent Context Design File: #{parent_design_file_path}

      Design Rules:
      #{rules_text}

      Document Specifications:
      #{document_spec}

      Write the document to #{design_file_path}.
      """

    {:ok, prompt}
  end
end
