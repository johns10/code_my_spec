defmodule CodeMySpec.MCPServers.Stories.Tools.SetStoryComponent do
  @moduledoc "Assigns a component to a story"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Stories
  alias CodeMySpec.MCPServers.Stories.StoriesMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
    field :story_id, :string, required: true
    field :component_id, :string, required: true
  end

  @impl true
  def execute(%{"story_id" => story_id, "component_id" => component_id}, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame),
         {:ok, story} <- Stories.get_story(scope, story_id),
         {:ok, updated_story} <- Stories.set_story_component(scope, story, component_id) do
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