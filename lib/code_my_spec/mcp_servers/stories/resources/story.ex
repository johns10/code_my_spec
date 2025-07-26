defmodule CodeMySpec.MCPServers.Stories.Resources.Story do
  use Hermes.Server.Component, type: :resource

  alias CodeMySpec.Stories
  alias CodeMySpec.MCPServers.Stories.StoriesMapper
  alias CodeMySpec.MCPServers.Validators

  def uri_template, do: "story://{story_id}"
  def uri, do: "story://template"
  def mime_type, do: "application/json"

  def read(%{"story_id" => story_id}, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame),
         story <- Stories.get_story(scope, story_id) do
      response = StoriesMapper.story_resource(story)
      {:reply, response, frame}
    else
      {:error, reason} ->
        error = %Hermes.MCP.Error{code: -1, message: "Failed to read story", reason: reason}
        {:error, error, frame}
    end
  end
end
