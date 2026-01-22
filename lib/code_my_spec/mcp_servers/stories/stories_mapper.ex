defmodule CodeMySpec.MCPServers.Stories.StoriesMapper do
  @moduledoc false

  alias CodeMySpec.MCPServers.Formatters
  alias Hermes.Server.Response

  def story_response(story) do
    Response.tool()
    |> Response.json(%{
      id: story.id,
      title: story.title,
      description: story.description,
      acceptance_criteria: story.acceptance_criteria,
      criteria: format_criteria(story.criteria),
      component_id: story.component_id
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
      acceptance_criteria: story.acceptance_criteria,
      criteria: format_criteria(story.criteria),
      component_id: story.component_id
    })
  end

  def stories_list_resource(stories) do
    Response.resource()
    |> Response.json(%{
      stories: Enum.map(stories, &story_summary/1)
    })
  end

  def stories_list_response(stories) do
    Response.tool()
    |> Response.json(%{
      stories: Enum.map(stories, &story_summary/1)
    })
  end

  def not_found_error do
    Response.tool()
    |> Response.error("Resource not found")
  end

  def stories_batch_response(stories) do
    Response.tool()
    |> Response.json(%{
      success: true,
      count: length(stories),
      stories: Enum.map(stories, &story_summary/1)
    })
  end

  def batch_errors_response(successes, failures) do
    Response.tool()
    |> Response.json(%{
      success: false,
      created_count: length(successes),
      failed_count: length(failures),
      created_stories: Enum.map(successes, &story_summary/1),
      errors:
        Enum.map(failures, fn {index, changeset} ->
          %{
            index: index,
            errors: Formatters.format_changeset_errors(changeset)
          }
        end)
    })
  end

  def prompt_response(prompt) do
    Response.tool()
    |> Response.json(%{
      content: prompt
    })
  end

  defp story_summary(story) do
    base = %{
      id: story.id,
      title: story.title,
      description: story.description,
      component_id: story.component_id
    }

    # Include criteria if loaded
    if Ecto.assoc_loaded?(story.criteria) do
      Map.put(base, :criteria, format_criteria(story.criteria))
    else
      base
    end
  end

  defp format_criteria(criteria) when is_list(criteria) do
    Enum.map(criteria, fn c ->
      %{
        id: c.id,
        description: c.description,
        verified: c.verified,
        verified_at: c.verified_at
      }
    end)
  end

  defp format_criteria(_), do: []
end
