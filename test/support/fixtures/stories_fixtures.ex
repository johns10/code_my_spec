defmodule CodeMySpec.StoriesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CodeMySpec.Stories` context.
  """

  @doc """
  Generate a story.
  """
  def story_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        acceptance_criteria: ["option1", "option2"],
        description: "some description",
        lock_expires_at: ~U[2025-07-17 12:48:00Z],
        locked_at: ~U[2025-07-17 12:48:00Z],
        priority: 42,
        status: :in_progress,
        title: "some title"
      })

    {:ok, story} = CodeMySpec.Stories.create_story(scope, attrs)
    story
  end
end
