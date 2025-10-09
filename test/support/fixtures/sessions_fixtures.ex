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
        agent: :claude_code,
        environment: :local,
        state: %{},
        status: :active,
        type: CodeMySpec.ContextDesignSessions
      })

    {:ok, session} = CodeMySpec.Sessions.create_session(scope, attrs)

    # Reload with same preloads as list_sessions/1
    CodeMySpec.Repo.preload(session, [:project, :component])
  end
end
