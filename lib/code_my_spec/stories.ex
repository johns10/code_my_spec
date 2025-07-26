defmodule CodeMySpec.Stories do
  @moduledoc """
  The Stories context.
  """

  alias CodeMySpec.Stories.Story
  alias CodeMySpec.Users.Scope
  alias CodeMySpec.Stories.StoriesRepository

  @doc """
  Subscribes to scoped notifications about any story changes.

  The broadcasted messages match the pattern:

    * {:created, %Story{}}
    * {:updated, %Story{}}
    * {:deleted, %Story{}}

  """
  def subscribe_stories(%Scope{} = scope) do
    key = scope.active_account.id

    Phoenix.PubSub.subscribe(CodeMySpec.PubSub, "user:#{key}:stories")
  end

  defp broadcast(%Scope{} = scope, message) do
    key = scope.active_account.id

    Phoenix.PubSub.broadcast(CodeMySpec.PubSub, "user:#{key}:stories", message)
  end

  @doc """
  Returns the list of stories.

  ## Examples

      iex> list_stories(scope)
      [%Story{}, ...]

  """
  defdelegate list_stories(scope), to: StoriesRepository

  @doc """
  Gets a single story.

  Raises `Ecto.NoResultsError` if the Story does not exist.

  ## Examples

      iex> get_story!(123)
      %Story{}

      iex> get_story!(456)
      ** (Ecto.NoResultsError)

  """
  defdelegate get_story!(scope, id), to: StoriesRepository
  defdelegate get_story(scope, id), to: StoriesRepository

  @doc """
  Creates a story.

  ## Examples

      iex> create_story(%{field: value})
      {:ok, %Story{}}

      iex> create_story(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_story(%Scope{} = scope, attrs) do
    with {:ok, story = %Story{}} <- StoriesRepository.create_story(scope, attrs) do
      broadcast(scope, {:created, story})
      {:ok, story}
    end
  end

  @doc """
  Updates a story.

  ## Examples

      iex> update_story(story, %{field: new_value})
      {:ok, %Story{}}

      iex> update_story(story, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_story(%Scope{} = scope, %Story{} = story, attrs) do
    true = story.account_id == scope.active_account.id

    with {:ok, story = %Story{}} <- StoriesRepository.update_story(scope, story, attrs) do
      broadcast(scope, {:updated, story})
      {:ok, story}
    end
  end

  @doc """
  Deletes a story.

  ## Examples

      iex> delete_story(story)
      {:ok, %Story{}}

      iex> delete_story(story)
      {:error, %Ecto.Changeset{}}

  """
  def delete_story(%Scope{} = scope, %Story{} = story) do
    true = story.account_id == scope.active_account.id

    with {:ok, story = %Story{}} <- StoriesRepository.delete_story(scope, story) do
      broadcast(scope, {:deleted, story})
      {:ok, story}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking story changes.

  ## Examples

      iex> change_story(story)
      %Ecto.Changeset{data: %Story{}}

  """
  def change_story(%Scope{} = scope, %Story{} = story, attrs \\ %{}) do
    true = story.account_id == scope.active_account.id

    Story.changeset(story, attrs, scope)
  end
end
