defmodule CodeMySpec.MCPServers.Stories.Tools.ClearStoryComponent do
  @moduledoc "Clears the component assignment from a story"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Stories
  alias CodeMySpec.MCPServers.Stories.StoriesMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
    field :story_id, :string, required: true
  end

  @impl true
  def execute(%{"story_id" => story_id}, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame),
         {:ok, story} <- Stories.get_story(scope, story_id),
         {:ok, updated_story} <- Stories.clear_story_component(scope, story) do
      {:reply, StoriesMapper.story_response(updated_story), frame}
    else
      {:error, changeset = %Ecto.Changeset{}} ->
        {:reply, StoriesMapper.validation_error(changeset), frame}

      {:error, :not_found} ->
        {:reply, StoriesMapper.error("Story not found"), frame}

      {:error, atom} ->
        {:reply, StoriesMapper.error(atom), frame}
    end
  end
end
