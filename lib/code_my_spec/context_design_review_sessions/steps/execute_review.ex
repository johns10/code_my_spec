defmodule CodeMySpec.ContextDesignReviewSessions.Steps.ExecuteReview do
  @moduledoc """
  Generates a comprehensive review command that instructs Claude to analyze Phoenix context
  documentation and all child component designs holistically.

  Gathers file paths for context design, child component designs, user stories, and project
  executive summary, then constructs a detailed prompt that directs Claude to validate
  architectural compatibility, check for integration issues, fix any issues found, and write
  a review summary to a specified file path.
  """

  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.{Components, Stories, Utils}
  alias CodeMySpec.Sessions.{Session, Steps.Helpers}
  alias CodeMySpec.Users.Scope

  @doc """
  Generates a command that instructs Claude to review the context design and all child
  component designs.

  Returns `{:ok, Command.t()}` with a comprehensive review prompt, or `{:error, String.t()}`
  if required data is missing.
  """
  def get_command(%Scope{} = scope, %Session{} = session, opts \\ []) do
    with {:ok, context_component} <- extract_context_component(session),
         {:ok, project} <- extract_project(session),
         {:ok, context_design_path} <- get_context_design_path(context_component, project),
         {:ok, child_design_paths} <- get_child_design_paths(scope, context_component, project),
         {:ok, stories} <- get_user_stories(scope, context_component),
         {:ok, review_file_path} <- calculate_review_file_path(context_design_path),
         {:ok, prompt} <-
           build_review_prompt(
             project,
             context_component,
             context_design_path,
             child_design_paths,
             stories,
             review_file_path
           ),
         {:ok, command} <-
           Helpers.build_agent_command(
             __MODULE__,
             :context_reviewer,
             "context-design-reviewer",
             prompt,
             opts
           ) do
      {:ok, command}
    end
  end

  @doc """
  Pass-through handler that returns empty session updates and the result unchanged.

  The review file is written by the client, so no session state needs to be modified.
  """
  def handle_result(_scope, _session, result, _opts \\ []) do
    {:ok, %{}, result}
  end

  # ============================================================================
  # Private Functions - Data Extraction
  # ============================================================================

  defp extract_context_component(%Session{component: nil, component_id: nil}) do
    {:error, "Session must have an associated component"}
  end

  defp extract_context_component(%Session{component: %{} = component}) do
    {:ok, component}
  end

  defp extract_context_component(%Session{component: nil, component_id: component_id})
       when is_integer(component_id) do
    {:error, "Session component_id #{component_id} is invalid or component not preloaded"}
  end

  defp extract_project(%Session{project: nil, project_id: nil}) do
    {:error, "Session must have an associated project"}
  end

  defp extract_project(%Session{project: %{} = project}) do
    {:ok, project}
  end

  defp extract_project(%Session{project: nil, project_id: project_id})
       when is_integer(project_id) do
    {:error, "Session project_id #{project_id} is invalid or project not preloaded"}
  end

  defp get_context_design_path(context_component, project) do
    %{design_file: design_file_path} = Utils.component_files(context_component, project)
    {:ok, design_file_path}
  end

  defp get_child_design_paths(scope, context_component, project) do
    child_components = Components.list_child_components(scope, context_component.id)

    child_paths =
      child_components
      |> Enum.map(fn child ->
        %{design_file: design_file_path} = Utils.component_files(child, project)
        design_file_path
      end)

    {:ok, child_paths}
  end

  defp get_user_stories(scope, context_component) do
    stories = Stories.list_component_stories(scope, context_component.id)
    {:ok, stories}
  end

  defp calculate_review_file_path(context_design_path) do
    # Context design path: "docs/design/code_my_spec/sessions.md"
    # Review file path: "docs/design/code_my_spec/sessions/design_review.md"
    review_path =
      context_design_path
      |> String.replace_suffix(".md", "/design_review.md")

    {:ok, review_path}
  end

  # ============================================================================
  # Private Functions - Prompt Building
  # ============================================================================

  defp build_review_prompt(
         project,
         context_component,
         context_design_path,
         child_design_paths,
         stories,
         review_file_path
       ) do
    prompt = """
    # Context Design Review

    You are conducting a comprehensive review of a Phoenix context design and all its child component designs.

    ## Project Information

    **Project:** #{project.name}
    **Description:** #{project.description || "No description provided"}

    ## Context Being Reviewed

    **Context Name:** #{context_component.name}
    **Module Name:** #{context_component.module_name}
    **Type:** #{context_component.type}
    **Description:** #{context_component.description || "No description provided"}

    ## Design Files to Review

    ### Context Design File
    #{context_design_path}

    ### Child Component Design Files
    #{format_child_design_paths(child_design_paths)}

    ## User Stories This Context Satisfies

    #{format_user_stories(stories)}

    #{format_project_executive_summary(project)}

    ## Review Instructions

    Please perform a comprehensive architectural review:

    1. **Read All Design Files**: Read the context design file and all child component design files to understand the complete architecture.

    2. **Validate Architectural Consistency**:
       - Ensure the context design aligns with Phoenix architectural patterns
       - Verify child components follow proper separation of concerns
       - Check that dependencies between components are logical and necessary
       - Validate that component types (repository, schema, liveview, etc.) are used appropriately

    3. **Check Integration Points**:
       - Verify that child components integrate properly with the context
       - Check for missing dependencies or circular dependencies
       - Ensure data flow between components is clear and maintainable
       - Validate that public APIs are well-defined and consistent

    4. **Verify User Story Alignment**:
       - Confirm the context design addresses all user stories
       - Check that acceptance criteria can be satisfied by the architecture
       - Identify any gaps between requirements and implementation

    5. **Fix Any Issues Found**:
       - If you find architectural inconsistencies, update the design files to fix them
       - If child components have integration issues, correct them in the appropriate design files
       - Ensure all fixes maintain consistency across all design files

    6. **Write Review Summary**:
       - Document your findings, including what was reviewed
       - List any issues found and how they were fixed
       - Confirm architectural soundness and readiness for implementation
       - Write your comprehensive review to: **#{review_file_path}**

    ## Expected Outcomes

    - All design files are architecturally consistent
    - Integration between context and child components is sound
    - User stories can be satisfied by the proposed design
    - Any issues found are fixed in the design files
    - A comprehensive review document is written to the specified path

    Please begin your review now.
    """

    {:ok, prompt}
  end

  defp format_child_design_paths([]) do
    "No child components to review."
  end

  defp format_child_design_paths(paths) do
    paths
    |> Enum.map(fn path -> "- #{path}" end)
    |> Enum.join("\n")
  end

  defp format_user_stories([]) do
    "No user stories have been associated with this context."
  end

  defp format_user_stories(stories) do
    stories
    |> Enum.with_index(1)
    |> Enum.map_join("\n\n", fn {story, index} ->
      format_single_story(story, index)
    end)
  end

  defp format_single_story(story, index) do
    acceptance_criteria = format_acceptance_criteria(story.acceptance_criteria)

    """
    ### Story #{index}: #{story.title}

    **Description:** #{story.description}

    **Acceptance Criteria:**
    #{acceptance_criteria}
    """
    |> String.trim()
  end

  defp format_acceptance_criteria([]) do
    "- None specified"
  end

  defp format_acceptance_criteria(criteria) when is_list(criteria) do
    criteria
    |> Enum.map(fn criterion -> "- #{criterion}" end)
    |> Enum.join("\n")
  end

  defp format_project_executive_summary(%{executive_summary: nil}) do
    ""
  end

  defp format_project_executive_summary(%{executive_summary: executive_summary})
       when is_binary(executive_summary) and executive_summary != "" do
    """
    ## Project Executive Summary

    #{executive_summary}
    """
  end

  defp format_project_executive_summary(_project) do
    ""
  end
end
