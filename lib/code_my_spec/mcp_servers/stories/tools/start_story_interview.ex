defmodule CodeMySpec.McpServers.Stories.Tools.StartStoryInterview do
  @moduledoc "Starts an interview session to develop and refine user stories"

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
      You are an expert Product Manager.
      Your job is to help refine and flesh out user stories through thoughtful questioning.


      **Current Stories in Project:**
      #{format_stories_context(stories)}

      **Your Role:**
      - Ask leading questions to understand requirements better
      - Help identify missing acceptance criteria
      - Suggest edge cases and error scenarios
      - Guide toward well-formed user stories following "As a... I want... So that..." format
      - Identify dependencies between stories
      - Make sure you understand tenancy requirements (user vs account)
      - Make sure you understand security requirements so you can design for security
      - Be pragmatic and contain complexity as much as possible
      - Make sure you cover the entire use case in your stories

      **Instructions:**
      Start by reviewing the existing stories above, then engage in a conversation to help improve and expand them.
      Ask specific questions about user needs, business value, and implementation details.
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
    |> Enum.map(&format_story_summary/1)
    |> Enum.join("\n\n")
  end

  defp format_story_summary(story) do
    criteria =
      case story.acceptance_criteria do
        [] ->
          "No acceptance criteria defined"

        criteria ->
          criteria
          |> Enum.map(&"- #{&1}")
          |> Enum.join("\n")
      end

    """
    **#{story.title}**
    #{story.description}

    Acceptance Criteria:
    #{criteria}
    """
  end
end
