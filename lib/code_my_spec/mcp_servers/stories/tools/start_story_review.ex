defmodule CodeMySpec.McpServers.Stories.Tools.StartStoryReview do
  @moduledoc "Starts a comprehensive review of user stories in a project"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Stories
  alias CodeMySpec.McpServers.Stories.StoriesMapper
  alias CodeMySpec.McpServers.Validators

  schema do
  end

  @impl true
  def execute(_params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame) do
      stories = Stories.list_project_stories(scope)

      prompt = """
      You are an expert Product Manager conducting a comprehensive story review.
      Your job is to evaluate the completeness and quality of user stories.

      **Current Stories in Project:**
      #{format_stories_context(stories)}

      **Your Review Criteria:**
      - Story follows "As a... I want... So that..." format
      - Business value is clearly articulated
      - Acceptance criteria are specific and testable
      - Story is appropriately sized (not too large or too small)
      - Dependencies and relationships are identified
      - Edge cases and error scenarios are considered

      **Your Review Process:**
      1. Evaluate each story against the criteria above
      2. Identify gaps, inconsistencies, or areas for improvement
      3. Suggest specific enhancements or clarifications
      4. Highlight potential risks or implementation challenges

      **Instructions:**
      Provide a comprehensive review of the stories above, focusing on completeness, clarity, and technical feasibility.
      Give specific, actionable feedback for each story.
      """

      {:reply, StoriesMapper.prompt_response(prompt), frame}
    else
      {:error, atom} ->
        {:reply, StoriesMapper.error(atom), frame}
    end
  end

  defp format_stories_context([]), do: "No stories currently exist for this project."

  defp format_stories_context(stories) do
    stories
    |> Enum.with_index(1)
    |> Enum.map(&format_story_for_review/1)
    |> Enum.join("\n\n")
  end

  defp format_story_for_review({story, index}) do
    criteria =
      case story.acceptance_criteria do
        [] ->
          "❌ No acceptance criteria defined"

        criteria ->
          criteria
          |> Enum.map(&"✓ #{&1}")
          |> Enum.join("\n")
      end

    """
    **Story #{index}: #{story.title}**
    Description: #{story.description}

    Acceptance Criteria:
    #{criteria}
    """
  end
end
