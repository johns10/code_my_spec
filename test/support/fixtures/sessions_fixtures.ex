defmodule CodeMySpec.SessionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CodeMySpec.Sessions` context.
  """

  @doc """
  Generate a session.
  """
  def session_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        environment_id: "some environment_id",
        state: %{},
        status: "some status",
        type: :design
      })

    {:ok, session} = CodeMySpec.Sessions.create_session(scope, attrs)
    session
  end
end
