defmodule CodeMySpec.MCPServers.Stories.Tools.ListStories do
  @moduledoc "Lists all stories in a project"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.Stories
  alias CodeMySpec.MCPServers.Stories.StoriesMapper
  alias CodeMySpec.MCPServers.Validators

  schema do
    field :project_id, :string, required: true
  end

  @impl true
  def execute(params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame) do
      stories =
        Stories.list_stories(scope)
        |> Enum.filter(&(&1.project_id == params.project_id))

      {:reply, StoriesMapper.stories_list_resource(stories, params.project_id), frame}
    else
      {:error, changeset = %Ecto.Changeset{}} ->
        {:reply, StoriesMapper.validation_error(changeset), frame}

      {:error, atom} ->
        {:reply, StoriesMapper.error(atom), frame}
    end
  end
end
