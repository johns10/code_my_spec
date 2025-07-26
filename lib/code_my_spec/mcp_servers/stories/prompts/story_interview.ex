defmodule CodeMySpec.MCPServers.Stories.Prompts.StoryInterview do
  use Hermes.Server.Component, type: :prompt

  alias CodeMySpec.Stories
  alias CodeMySpec.MCPServers.Validators

  schema do
    field :project_id, :string, required: true
  end

  def get_messages(%{"project_id" => project_id}, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame) do
      stories =
        Stories.list_stories(scope)
        |> Enum.filter(&(&1.project_id == project_id))

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

      messages = [%{"role" => "system", "content" => prompt}]
      {:ok, messages, frame}
    else
      {:error, reason} ->
        error = %Hermes.MCP.Error{code: -1, message: "Failed to generate prompt", reason: reason}
        {:error, error, frame}
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
