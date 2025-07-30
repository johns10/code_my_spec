defmodule CodeMySpec.MCPServers.Stories.Tools.GetStory do
  @moduledoc "Gets a single story by ID"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Stories
  alias CodeMySpec.MCPServers.Stories.StoriesMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
    field :story_id, :string, required: true
  end

  @impl true
  def execute(params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame),
         story <- Stories.get_story!(scope, params.story_id) do
      {:reply, StoriesMapper.story_response(story), frame}
    else
      {:error, atom} ->
        {:reply, StoriesMapper.error(atom), frame}
    end
  end
end
