defmodule CodeMySpec.MCPServers.Stories.Tools.CreateStory do
  @moduledoc "Creates a user story"

  use Hermes.Server.Component, type: :tool

  alias CodeMySpec.MCPServers.Stories.StoriesMapper
  alias CodeMySpec.MCPServers.Validators
  alias CodeMySpec.Stories

  schema do
    field :title, :string, required: true
    field :description, :string, required: true
    field :acceptance_criteria, {:list, :string}, required: true
  end

  @impl true
  def execute(params, frame) do
    with {:ok, scope} <- Validators.validate_scope(frame),
         story_params <- transform_params(params),
         {:ok, story} <- Stories.create_story(scope, story_params) do
      {:reply, StoriesMapper.story_response(story), frame}
    else
      {:error, changeset = %Ecto.Changeset{}} ->
        {:reply, StoriesMapper.validation_error(changeset), frame}

      {:error, atom} ->
        {:reply, StoriesMapper.error(atom), frame}
    end
  end

  # Transform acceptance_criteria strings to criteria nested params
  defp transform_params(params) do
    criteria =
      params
      |> Map.get(:acceptance_criteria, [])
      |> Enum.map(fn description -> %{description: description} end)

    params
    |> Map.put(:criteria, criteria)
  end
end
