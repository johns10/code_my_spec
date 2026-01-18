defmodule CodeMySpec.SessionsTest do
  alias CodeMySpec.ContextSpecSessions
  use CodeMySpec.DataCase

  alias CodeMySpec.Sessions

  describe "sessions" do
    alias CodeMySpec.Sessions.Session

    import CodeMySpec.UsersFixtures, only: [full_scope_fixture: 0]
    import CodeMySpec.SessionsFixtures

    @invalid_attrs %{status: nil, type: nil, state: nil, agent: nil, environment: nil}

    test "list_sessions/1 returns all scoped sessions" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()
      session = session_fixture(scope)
      other_session = session_fixture(other_scope)
      assert Sessions.list_sessions(scope) == [session]
      assert Sessions.list_sessions(other_scope) == [other_session]
    end

    test "get_session!/2 returns the session with given id" do
      scope = full_scope_fixture()
      session = session_fixture(scope)
      other_scope = full_scope_fixture()
      reloaded_session = Sessions.get_session!(scope, session.id)
      assert session.id == reloaded_session.id
      assert session.status == reloaded_session.status
      assert session.type == reloaded_session.type
      assert session.state == reloaded_session.state
      assert_raise Ecto.NoResultsError, fn -> Sessions.get_session!(other_scope, session.id) end
    end

    test "create_session/2 with valid data creates a session" do
      valid_attrs = %{
        status: :active,
        type: ContextSpecSessions,
        state: %{},
        agent: :claude_code,
        environment: :local
      }

      scope = full_scope_fixture()

      assert {:ok, %Session{} = session} = Sessions.create_session(scope, valid_attrs)
      assert session.status == :active
      assert session.type == ContextSpecSessions
      assert session.state == %{}
      assert session.agent == :claude_code
      assert session.environment == :local
      assert session.account_id == scope.active_account.id
    end

    test "create_session/2 with invalid data returns error changeset" do
      scope = full_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Sessions.create_session(scope, @invalid_attrs)
    end

    test "update_session/3 with valid data updates the session" do
      scope = full_scope_fixture()
      session = session_fixture(scope)

      update_attrs = %{
        status: :complete,
        type: ContextSpecSessions,
        state: %{},
        agent: :claude_code,
        environment: :vscode
      }

      assert {:ok, %Session{} = session} = Sessions.update_session(scope, session, update_attrs)
      assert session.status == :complete
      assert session.type == ContextSpecSessions
      assert session.state == %{}
      assert session.agent == :claude_code
      assert session.environment == :vscode
    end

    test "update_session/3 with invalid scope raises" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()
      session = session_fixture(scope)

      assert_raise MatchError, fn ->
        Sessions.update_session(other_scope, session, %{})
      end
    end

    test "update_session/3 with invalid data returns error changeset" do
      scope = full_scope_fixture()
      session = session_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Sessions.update_session(scope, session, @invalid_attrs)
      reloaded_session = Sessions.get_session!(scope, session.id)
      assert session.id == reloaded_session.id
      assert session.status == reloaded_session.status
      assert session.type == reloaded_session.type
      assert session.state == reloaded_session.state
    end

    test "delete_session/2 deletes the session" do
      scope = full_scope_fixture()
      session = session_fixture(scope)
      assert {:ok, %Session{}} = Sessions.delete_session(scope, session)
      assert_raise Ecto.NoResultsError, fn -> Sessions.get_session!(scope, session.id) end
    end

    test "delete_session/2 with invalid scope raises" do
      scope = full_scope_fixture()
      other_scope = full_scope_fixture()
      session = session_fixture(scope)
      assert_raise MatchError, fn -> Sessions.delete_session(other_scope, session) end
    end

    test "change_session/2 returns a session changeset" do
      scope = full_scope_fixture()
      session = session_fixture(scope)
      assert %Ecto.Changeset{} = Sessions.change_session(scope, session)
    end

    test "update_execution_mode/3 updates session execution mode" do
      scope = full_scope_fixture()
      session = session_fixture(scope, %{execution_mode: :manual})

      assert session.execution_mode == :manual

      assert {:ok, updated_session} = Sessions.update_execution_mode(scope, session.id, "auto")
      assert updated_session.execution_mode == :auto
      assert updated_session.id == session.id
    end

    test "update_execution_mode/3 with invalid mode returns error" do
      scope = full_scope_fixture()
      session = session_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Sessions.update_execution_mode(scope, session.id, "invalid")
    end

    test "update_execution_mode/3 with non-existent session returns error" do
      scope = full_scope_fixture()
      fake_uuid = "00000000-0000-0000-0000-000000000000"

      assert {:error, :session_not_found} = Sessions.update_execution_mode(scope, fake_uuid, "auto")
    end

    test "update_execution_mode/3 regenerates pending command with new mode" do
      scope = full_scope_fixture()

      # Create a component for ContextSpecSessions
      {:ok, component} =
        CodeMySpec.Components.create_component(scope, %{
          name: "TestContext",
          type: "context",
          module_name: "TestContext",
          description: "Test context"
        })

      # Create session
      session =
        session_fixture(scope, %{
          type: ContextSpecSessions,
          execution_mode: :manual,
          component_id: component.id
        })

      # Complete the Initialize step first
      {:ok, session_after_init} = Sessions.next_command(scope, session.id)
      [init_interaction] = session_after_init.interactions

      {:ok, session_init_complete} =
        Sessions.handle_result(scope, session.id, init_interaction.id, %{
          status: :ok,
          code: 0
        })

      # Now get the GenerateContextSpec command
      {:ok, session_with_command} = Sessions.next_command(scope, session_init_complete.id)
      [pending_interaction, _init] = session_with_command.interactions

      assert pending_interaction.result == nil
      assert pending_interaction.command.command == "claude"

      # Change execution mode to auto
      assert {:ok, updated_session} =
               Sessions.update_execution_mode(scope, session_with_command.id, "auto")

      assert updated_session.execution_mode == :auto

      # Refetch from database to get properly serialized metadata
      refetched_session = Sessions.get_session!(scope, updated_session.id)
      [updated_interaction, _init] = refetched_session.interactions

      # Command should be regenerated with auto mode
      assert updated_interaction.id != pending_interaction.id
      updated_command_metadata = updated_interaction.command.metadata

      # The auto flag should be in the options (after DB round-trip, keys are strings)
      options = Map.get(updated_command_metadata, "options", %{})
      assert options["auto"] == true
    end

    test "update_execution_mode/3 does not regenerate if no pending interaction" do
      scope = full_scope_fixture()
      session = session_fixture(scope, %{execution_mode: :manual})

      # No interactions, so no command to regenerate
      assert {:ok, updated_session} = Sessions.update_execution_mode(scope, session.id, "auto")
      assert updated_session.execution_mode == :auto
      assert updated_session.interactions == []
    end
  end
end
