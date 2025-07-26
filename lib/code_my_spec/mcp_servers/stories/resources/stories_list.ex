defmodule CodeMySpec.MCPServers.Stories.Resources.StoriesList do
  use Hermes.Server.Component, type: :resource

  alias CodeMySpec.Stories
  alias CodeMySpec.MCPServers.Stories.StoriesMapper
  alias CodeMySpec.MCPServers.Validators

  def uri_template, do: "stories://project/{project_id}"
  def uri, do: "stories://project/template"
  def mime_type, do: "application/json"

  def read(%{"project_id" => project_id}, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame) do
      stories = Stories.list_stories(scope)
                |> Enum.filter(&(&1.project_id == project_id))

      response = StoriesMapper.stories_list_resource(stories, project_id)
      {:reply, response, frame}
    else
      {:error, reason} ->
        error = %Hermes.MCP.Error{code: -1, message: "Failed to read stories list", reason: reason}
        {:error, error, frame}
    end
  end
end