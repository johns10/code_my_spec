defmodule CodeMySpec.SessionsTest do
  alias CodeMySpec.ContextDesignSessions
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
        type: ContextDesignSessions,
        state: %{},
        agent: :claude_code,
        environment: :local
      }

      scope = full_scope_fixture()

      assert {:ok, %Session{} = session} = Sessions.create_session(scope, valid_attrs)
      assert session.status == :active
      assert session.type == ContextDesignSessions
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
        type: ContextDesignSessions,
        state: %{},
        agent: :claude_code,
        environment: :vscode
      }

      assert {:ok, %Session{} = session} = Sessions.update_session(scope, session, update_attrs)
      assert session.status == :complete
      assert session.type == ContextDesignSessions
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
  end
end
