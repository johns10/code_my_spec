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

  @doc """
  Generate valid event attributes for testing.
  """
  def valid_event_attrs(session_id, attrs \\ %{}) do
    Enum.into(attrs, %{
      session_id: session_id,
      event_type: :tool_called,
      sent_at: DateTime.utc_now(),
      data: %{
        "tool_name" => "Read",
        "file_path" => "/path/to/file.ex"
      }
    })
  end

  @doc """
  Generate a conversation_started event.
  """
  def conversation_started_event_attrs(session_id, conversation_id, attrs \\ %{}) do
    Enum.into(attrs, %{
      session_id: session_id,
      event_type: :conversation_started,
      sent_at: DateTime.utc_now(),
      data: %{
        "conversation_id" => conversation_id,
        "agent" => "claude_code",
        "model" => "claude-sonnet-4"
      }
    })
  end

  @doc """
  Generate a tool_called event.
  """
  def tool_called_event_attrs(session_id, attrs \\ %{}) do
    Enum.into(attrs, %{
      session_id: session_id,
      event_type: :tool_called,
      sent_at: DateTime.utc_now(),
      data: %{
        "tool_name" => "Read",
        "parameters" => %{"file_path" => "/path/to/file.ex"}
      }
    })
  end

  @doc """
  Generate a file_modified event.
  """
  def file_modified_event_attrs(session_id, attrs \\ %{}) do
    Enum.into(attrs, %{
      session_id: session_id,
      event_type: :file_modified,
      sent_at: DateTime.utc_now(),
      data: %{
        "file_path" => "/path/to/file.ex",
        "lines_added" => 10,
        "lines_removed" => 5
      }
    })
  end

  @doc """
  Generate an error_occurred event.
  """
  def error_occurred_event_attrs(session_id, attrs \\ %{}) do
    Enum.into(attrs, %{
      session_id: session_id,
      event_type: :error_occurred,
      sent_at: DateTime.utc_now(),
      data: %{
        error_type: "compilation_error",
        message: "Undefined function foo/1",
        file: "/path/to/file.ex",
        line: 42
      }
    })
  end
end
