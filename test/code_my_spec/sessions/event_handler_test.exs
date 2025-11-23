defmodule CodeMySpec.Sessions.EventHandlerTest do
  use CodeMySpec.DataCase
  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures, SessionsFixtures}
  import ExUnit.CaptureLog
  alias CodeMySpec.Sessions.EventHandler
  alias CodeMySpec.Repo

  describe "validation tests" do
    setup do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account)

      project =
        user_scope_fixture(user, account)
        |> project_fixture(%{account_id: account.id, module_name: "MyApp"})

      scope = user_scope_fixture(user, account, project)
      session = session_fixture(scope)

      %{scope: scope, session: session}
    end

    test "valid event with all required fields passes validation", %{
      scope: scope,
      session: session
    } do
      event_attrs = valid_event_attrs(session.id)

      assert {:ok, updated_session} = EventHandler.handle_event(scope, session.id, event_attrs)
      assert updated_session.id == session.id

      events = Repo.all(CodeMySpec.Sessions.SessionEvent)
      assert length(events) == 1

      event = List.first(events)
      assert event.session_id == session.id
      assert event.event_type == :proxy_response
      assert event.data["tool_name"] == "Read"
    end

    test "missing required fields fails validation", %{scope: scope, session: session} do
      # Missing event_type
      event_attrs =
        valid_event_attrs(session.id)
        |> Map.delete("event_type")

      assert {:error, changeset} = EventHandler.handle_event(scope, session.id, event_attrs)
      assert %{event_type: ["can't be blank"]} = errors_on(changeset)
      assert Repo.all(CodeMySpec.Sessions.SessionEvent) == []

      # Missing sent_at
      event_attrs =
        valid_event_attrs(session.id)
        |> Map.delete("sent_at")

      assert {:error, changeset} = EventHandler.handle_event(scope, session.id, event_attrs)
      assert %{sent_at: ["can't be blank"]} = errors_on(changeset)
      assert Repo.all(CodeMySpec.Sessions.SessionEvent) == []

      # Missing data
      event_attrs =
        valid_event_attrs(session.id)
        |> Map.delete("data")

      assert {:error, changeset} = EventHandler.handle_event(scope, session.id, event_attrs)
      assert %{data: ["can't be blank"]} = errors_on(changeset)
      assert Repo.all(CodeMySpec.Sessions.SessionEvent) == []
    end

    test "invalid event_type fails validation", %{scope: scope, session: session} do
      event_attrs =
        valid_event_attrs(session.id)
        |> Map.put("event_type", :invalid_event_type)

      assert {:error, changeset} = EventHandler.handle_event(scope, session.id, event_attrs)
      assert %{event_type: ["is invalid"]} = errors_on(changeset)
      assert Repo.all(CodeMySpec.Sessions.SessionEvent) == []
    end

    test "data field accepts any map structure", %{scope: scope, session: session} do
      # Simple map
      event_attrs =
        valid_event_attrs(session.id, %{
          "data" => %{"simple" => "value"}
        })

      assert {:ok, _} = EventHandler.handle_event(scope, session.id, event_attrs)

      # Nested map
      event_attrs =
        valid_event_attrs(session.id, %{
          "data" => %{
            "nested" => %{
              "deeply" => %{
                "structured" => ["data", "with", "arrays"]
              }
            }
          }
        })

      assert {:ok, _} = EventHandler.handle_event(scope, session.id, event_attrs)

      # Mixed types
      event_attrs =
        valid_event_attrs(session.id, %{
          "data" => %{
            "numbers" => 42,
            "booleans" => true,
            "strings" => "test",
            "lists" => [1, 2, 3],
            "maps" => %{"inner" => "value"}
          }
        })

      assert {:ok, _} = EventHandler.handle_event(scope, session.id, event_attrs)

      # Empty map
      event_attrs =
        valid_event_attrs(session.id, %{
          "data" => %{}
        })

      assert {:ok, _} = EventHandler.handle_event(scope, session.id, event_attrs)

      events = Repo.all(CodeMySpec.Sessions.SessionEvent)
      assert length(events) == 4
    end
  end

  describe "side effect tests" do
    setup do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account)

      project =
        user_scope_fixture(user, account)
        |> project_fixture(%{account_id: account.id, module_name: "MyApp"})

      scope = user_scope_fixture(user, account, project)
      session = session_fixture(scope)

      %{scope: scope, session: session}
    end

    test "conversation_started sets external_conversation_id when nil", %{
      scope: scope,
      session: session
    } do
      conversation_id = "conv_abc123"
      event_attrs = conversation_started_event_attrs(session.id, conversation_id)

      assert {:ok, updated_session} = EventHandler.handle_event(scope, session.id, event_attrs)
      assert updated_session.external_conversation_id == conversation_id

      reloaded_session = CodeMySpec.Sessions.get_session!(scope, session.id)
      assert reloaded_session.external_conversation_id == conversation_id

      events = Repo.all(CodeMySpec.Sessions.SessionEvent)
      assert length(events) == 1
      assert List.first(events).event_type == :session_start
    end

    test "conversation_started no-ops when already set to same value", %{
      scope: scope,
      session: session
    } do
      conversation_id = "conv_abc123"

      # First event sets the conversation_id
      event_attrs = conversation_started_event_attrs(session.id, conversation_id)
      assert {:ok, updated_session} = EventHandler.handle_event(scope, session.id, event_attrs)
      assert updated_session.external_conversation_id == conversation_id

      # Second event with same conversation_id should not change anything
      event_attrs2 = conversation_started_event_attrs(session.id, conversation_id)
      assert {:ok, updated_session2} = EventHandler.handle_event(scope, session.id, event_attrs2)
      assert updated_session2.external_conversation_id == conversation_id

      reloaded_session = CodeMySpec.Sessions.get_session!(scope, session.id)
      assert reloaded_session.external_conversation_id == conversation_id

      events = Repo.all(CodeMySpec.Sessions.SessionEvent)
      assert length(events) == 2
    end

    test "conversation_started logs warning when changing conversations", %{
      scope: scope,
      session: session
    } do
      first_conversation_id = "conv_abc123"
      second_conversation_id = "conv_xyz789"

      # First event sets the conversation_id
      event_attrs = conversation_started_event_attrs(session.id, first_conversation_id)
      assert {:ok, updated_session} = EventHandler.handle_event(scope, session.id, event_attrs)
      assert updated_session.external_conversation_id == first_conversation_id

      # Second event tries to change conversation_id
      # Should log warning but still process the event
      event_attrs2 = conversation_started_event_attrs(session.id, second_conversation_id)

      capture_log(fn ->
        assert {:ok, updated_session2} =
                 EventHandler.handle_event(scope, session.id, event_attrs2)

        # Session keeps original conversation_id (no change)
        assert updated_session2.external_conversation_id == first_conversation_id

        reloaded_session = CodeMySpec.Sessions.get_session!(scope, session.id)
        assert reloaded_session.external_conversation_id == first_conversation_id
      end)

      # Event is still persisted
      events = Repo.all(CodeMySpec.Sessions.SessionEvent)
      assert length(events) == 2
    end

    test "session_status_changed updates session status", %{scope: scope, session: session} do
      event_attrs =
        valid_event_attrs(session.id, %{
          "event_type" => :proxy_request,
          "data" => %{
            "old_status" => "active",
            "new_status" => "complete"
          }
        })

      assert {:ok, updated_session} = EventHandler.handle_event(scope, session.id, event_attrs)

      # Verify side effect applied
      assert updated_session.status == :complete

      reloaded_session = CodeMySpec.Sessions.get_session!(scope, session.id)
      assert reloaded_session.status == :complete

      events = Repo.all(CodeMySpec.Sessions.SessionEvent)
      assert length(events) == 1
      assert List.first(events).event_type == :proxy_request
    end

    test "unknown event types have no side effects", %{scope: scope, session: session} do
      # Test various event types that should have no side effects
      event_types = [:proxy_request, :proxy_response, :session_start]

      original_status = session.status
      original_state = session.state
      original_conversation_id = session.external_conversation_id

      for event_type <- event_types do
        event_attrs =
          valid_event_attrs(session.id, %{
            "event_type" => event_type,
            "data" => %{"test" => "data"}
          })

        assert {:ok, updated_session} = EventHandler.handle_event(scope, session.id, event_attrs)

        # No side effects - session unchanged
        assert updated_session.status == original_status
        assert updated_session.state == original_state
        assert updated_session.external_conversation_id == original_conversation_id
      end

      # All events persisted
      events = Repo.all(CodeMySpec.Sessions.SessionEvent)
      assert length(events) == length(event_types)
    end
  end

  describe "batch processing tests" do
    setup do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account)

      project =
        user_scope_fixture(user, account)
        |> project_fixture(%{account_id: account.id, module_name: "MyApp"})

      scope = user_scope_fixture(user, account, project)
      session = session_fixture(scope)

      %{scope: scope, session: session}
    end

    test "multiple valid events insert successfully", %{scope: scope, session: session} do
      events_attrs = [
        conversation_started_event_attrs(session.id, "conversation-id"),
        valid_event_attrs(session.id),
        valid_event_attrs(session.id, %{
          "event_type" => :proxy_request,
          "data" => %{"command" => "mix test"}
        })
      ]

      assert {:ok, updated_session} = EventHandler.handle_events(scope, session.id, events_attrs)
      assert updated_session.id == session.id

      events = Repo.all(CodeMySpec.Sessions.SessionEvent)
      assert length(events) == 3

      event_types = Enum.map(events, & &1.event_type)
      assert :proxy_response in event_types
      assert :proxy_request in event_types
      assert :session_start in event_types
    end

    test "first invalid event fails entire batch", %{scope: scope, session: session} do
      events_attrs = [
        valid_event_attrs(session.id),
        valid_event_attrs(session.id) |> Map.delete("sent_at"),
        valid_event_attrs(session.id)
      ]

      assert {:error, changeset} = EventHandler.handle_events(scope, session.id, events_attrs)
      assert %{sent_at: ["can't be blank"]} = errors_on(changeset)

      # No events persisted due to transaction rollback
      assert Repo.all(CodeMySpec.Sessions.SessionEvent) == []
    end

    test "transaction rolls back on error", %{scope: scope, session: session} do
      events_attrs = [
        valid_event_attrs(session.id),
        valid_event_attrs(session.id),
        # Last event is invalid
        valid_event_attrs(session.id) |> Map.put("event_type", :invalid_type)
      ]

      assert {:error, changeset} = EventHandler.handle_events(scope, session.id, events_attrs)
      assert %{event_type: ["is invalid"]} = errors_on(changeset)

      # No events persisted - entire batch rolled back
      assert Repo.all(CodeMySpec.Sessions.SessionEvent) == []
    end
  end

  describe "broadcast tests" do
    setup do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account)

      project =
        user_scope_fixture(user, account)
        |> project_fixture(%{account_id: account.id, module_name: "MyApp"})

      scope = user_scope_fixture(user, account, project)
      session = session_fixture(scope)

      # Subscribe to all relevant channels
      account_topic = "account:#{account.id}:sessions"
      user_topic = "user:#{user.id}:sessions"

      Phoenix.PubSub.subscribe(CodeMySpec.PubSub, account_topic)
      Phoenix.PubSub.subscribe(CodeMySpec.PubSub, user_topic)

      # Flush any messages from setup (like email confirmations)
      flush_mailbox()

      %{
        scope: scope,
        session: session,
        account: account,
        user: user,
        account_topic: account_topic,
        user_topic: user_topic
      }
    end

    defp flush_mailbox do
      receive do
        _ -> flush_mailbox()
      after
        0 -> :ok
      end
    end

    test "conversation_started broadcasts to account, user, and session channels", %{
      scope: scope,
      session: session
    } do
      conversation_id = "conv_test123"
      event_attrs = conversation_started_event_attrs(session.id, conversation_id)

      assert {:ok, _updated_session} = EventHandler.handle_event(scope, session.id, event_attrs)

      # Should receive the message 3 times (once per channel)
      assert_receive(
        {:conversation_id_set, %{session_id: session_id, conversation_id: ^conversation_id}},
        500
      )

      assert session_id == session.id

      assert_receive {:conversation_id_set,
                      %{session_id: ^session_id, conversation_id: ^conversation_id}}

      assert_receive {:session_activity, %{session_id: ^session_id}}
      assert_receive {:session_activity, %{session_id: ^session_id}}

      # Should not receive any more messages
      refute_receive _, 100
    end

    test "session_status_changed broadcasts to account and user channels only", %{
      scope: scope,
      session: session
    } do
      event_attrs =
        valid_event_attrs(session.id, %{
          "event_type" => :proxy_response,
          "data" => %{
            "old_status" => "active",
            "new_status" => "complete"
          }
        })

      assert {:ok, _updated_session} = EventHandler.handle_event(scope, session.id, event_attrs)
      assert_receive {:session_status_changed, %{session_id: session_id, status: :complete}}
      assert session_id == session.id

      assert_receive(
        {:session_status_changed, %{session_id: ^session_id, status: :complete}},
        500
      )

      # Should also receive session_event_received on session channel
      assert_receive {:session_activity, %{session_id: ^session_id}}
      assert_receive {:session_activity, %{session_id: ^session_id}}

      # Should not receive any more messages
      refute_receive _, 100
    end
  end
end
