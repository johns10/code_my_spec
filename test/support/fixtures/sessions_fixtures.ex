defmodule CodeMySpec.SessionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CodeMySpec.Sessions` context.
  """

  alias CodeMySpec.Sessions.{Command, Interaction, InteractionsRepository}

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
        type: CodeMySpec.ContextSpecSessions,
        display_name: "Context Design",
        interactions: []
      })

    {:ok, session} = CodeMySpec.Sessions.create_session(scope, attrs)

    # Reload with same preloads as list_sessions/1
    CodeMySpec.Repo.preload(session, [:project, :component, :interactions])
  end

  @doc """
  Generate an interaction for a session.
  """
  def interaction_fixture(session, attrs \\ %{}) do
    # Create a test command
    command =
      Command.new(
        Map.get(attrs, :module, CodeMySpec.ContextSpecSessions),
        Map.get(attrs, :command, "claude"),
        metadata: Map.get(attrs, :metadata, %{prompt: "Test prompt"})
      )

    # Create interaction with command
    interaction = Interaction.new_with_command(command)

    # Insert into database
    {:ok, created_interaction} = InteractionsRepository.create(session.id, interaction)

    created_interaction
  end

  @doc """
  Generate valid event attributes for testing.
  """
  def valid_event_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      "event_type" => :proxy_response,
      "sent_at" => DateTime.utc_now(),
      "data" => %{
        "tool_name" => "Read",
        "file_path" => "/path/to/file.ex"
      }
    })
  end

  @doc """
  Generate a conversation_started event.
  """
  def conversation_started_event_attrs(conversation_id, attrs \\ %{}) do
    Enum.into(attrs, %{
      "event_type" => :session_start,
      "sent_at" => DateTime.utc_now(),
      "data" => %{
        "session_id" => conversation_id,
        "agent" => "claude_code",
        "model" => "claude-sonnet-4"
      }
    })
  end
end
