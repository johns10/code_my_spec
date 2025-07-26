defmodule CodeMySpec.MCPServers.Stories.Tools.ListStories do
  @moduledoc "Lists all stories in a project"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Stories
  alias CodeMySpec.MCPServers.Stories.StoriesMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
  end

  @impl true
  def execute(params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame) do
      stories = Stories.list_project_stories(scope)
      {:reply, StoriesMapper.stories_list_response(stories), frame}
    else
      {:error, changeset = %Ecto.Changeset{}} ->
        {:reply, StoriesMapper.validation_error(changeset), frame}

      {:error, atom} ->
        {:reply, StoriesMapper.error(atom), frame}
    end
  end
end
