defmodule CodeMySpec.MCPServers.Stories.Tools.UpdateStory do
  @moduledoc """
  Updates a user story.
  Include all acceptance query in the input.
  It will be persisted exactly as you send it.
  """

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Stories
  alias CodeMySpec.MCPServers.Stories.StoriesMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
    field :id, :string, required: true
    field :title, :string
    field :description, :string
    field :acceptance_criteria, {:list, :string}
  end

  @impl true
  def execute(params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame),
         story <- Stories.get_story(scope, params.id),
         {:ok, story} <- Stories.update_story(scope, story, Map.drop(params, [:id])) do
      {:reply, StoriesMapper.story_response(story), frame}
    else
      {:error, changeset = %Ecto.Changeset{}} ->
        {:reply, StoriesMapper.validation_error(changeset), frame}

      {:error, atom} ->
        {:reply, StoriesMapper.error(atom), frame}
    end
  end
end
