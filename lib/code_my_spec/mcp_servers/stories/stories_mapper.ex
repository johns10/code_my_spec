defmodule CodeMySpec.MCPServers.Stories.StoriesMapper do
  alias Hermes.Server.Response
  alias CodeMySpec.MCPServers.Formatters

  def story_response(story) do
    Response.tool()
    |> Response.json(%{
      id: story.id,
      title: story.title,
      description: story.description,
      acceptance_criteria: story.acceptance_criteria
    })
  end

  def validation_error(changeset) do
    Response.tool()
    |> Response.error(Formatters.format_changeset_errors(changeset))
  end

  def error(error) when is_atom(error), do: error |> to_string() |> error()

  def error(error) when is_binary(error) do
    Response.tool()
    |> Response.error(error)
  end

  def story_resource(story) do
    Response.resource()
    |> Response.json(%{
      id: story.id,
      title: story.title,
      description: story.description,
      acceptance_criteria: story.acceptance_criteria
    })
  end

  def stories_list_resource(stories, project_id) do
    Response.resource()
    |> Response.json(%{
      project_id: project_id,
      stories: Enum.map(stories, &story_summary/1)
    })
  end

  def not_found_error do
    Response.tool()
    |> Response.error("Resource not found")
  end

  defp story_summary(story) do
    %{
      id: story.id,
      title: story.title,
      description: story.description
    }
  end
end
