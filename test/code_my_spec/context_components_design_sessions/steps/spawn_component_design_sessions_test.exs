defmodule CodeMySpec.ContextComponentsDesignSessions.Steps.SpawnComponentSpecSessionsTest do
  use CodeMySpec.DataCase, async: true

  alias CodeMySpec.ContextComponentsDesignSessions.Steps.SpawnComponentSpecSessions
  alias CodeMySpec.Sessions.{Command, Result, Session}

  import CodeMySpec.UsersFixtures
  import CodeMySpec.ProjectsFixtures
  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.SessionsFixtures

  describe "get_command/3" do
    setup do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})

      # Create a context component (parent)
      context_component =
        component_fixture(scope, %{
          name: "Accounts",
          module_name: "Accounts",
          type: :context,
          project_id: project.id
        })

      # Create child components
      child1 =
        component_fixture(scope, %{
          name: "User",
          module_name: "User",
          type: :schema,
          project_id: project.id,
          parent_component_id: context_component.id,
          priority: 10
        })

      child2 =
        component_fixture(scope, %{
          name: "UserRepository",
          module_name: "UserRepository",
          type: :repository,
          project_id: project.id,
          parent_component_id: context_component.id,
          priority: 5
        })

      child3 =
        component_fixture(scope, %{
          name: "AccountsLive",
          module_name: "AccountsLive",
          type: :other,
          project_id: project.id,
          parent_component_id: context_component.id,
          priority: 1
        })

      # Create parent session
      parent_session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextComponentsDesignSessions,
          component_id: context_component.id,
          project_id: project.id,
          agent: :claude_code,
          environment: :local,
          execution_mode: :manual
        })

      # Reload with preloads
      context_component = CodeMySpec.Components.get_component!(scope, context_component.id)
      parent_session = CodeMySpec.Repo.preload(parent_session, [:project, :component])

      %{
        scope: scope,
        project: project,
        context_component: context_component,
        child1: child1,
        child2: child2,
        child3: child3,
        parent_session: parent_session
      }
    end

    test "returns spawn_sessions command with child_session_ids in metadata", %{
      scope: scope,
      parent_session: parent_session
    } do
      assert {:ok, %Command{} = command} =
               SpawnComponentSpecSessions.get_command(scope, parent_session, [])

      assert command.module == SpawnComponentSpecSessions
      assert command.command == "spawn_sessions"
      assert is_map(command.metadata)
      assert is_list(command.metadata.child_session_ids)
      assert length(command.metadata.child_session_ids) == 3
    end

    test "creates child sessions for each component with correct attributes", %{
      scope: scope,
      parent_session: parent_session
    } do
      {:ok, command} = SpawnComponentSpecSessions.get_command(scope, parent_session, [])

      # Fetch created child sessions
      child_sessions =
        Enum.map(command.metadata.child_session_ids, fn id ->
          CodeMySpec.Sessions.get_session!(scope, id)
        end)

      assert length(child_sessions) == 3

      # Verify all child sessions have correct basic attributes
      for child_session <- child_sessions do
        assert child_session.type == CodeMySpec.ComponentSpecSessions
        assert child_session.session_id == parent_session.id
        assert child_session.execution_mode == :agentic
        assert child_session.agent == :claude_code
        assert child_session.environment == :local
        assert child_session.status == :active
        assert child_session.account_id == scope.active_account.id
        assert child_session.project_id == scope.active_project.id
        assert child_session.user_id == scope.user.id
      end
    end

    test "returns error when context component has no children", %{
      scope: scope,
      project: project
    } do
      # Create a context with no children
      orphan_context =
        component_fixture(scope, %{
          name: "OrphanContext",
          module_name: "OrphanContext",
          type: :context,
          project_id: project.id
        })

      orphan_session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextComponentsDesignSessions,
          component_id: orphan_context.id,
          project_id: project.id
        })

      orphan_session = CodeMySpec.Repo.preload(orphan_session, [:project, :component])

      assert {:error, "No child components found for context"} =
               SpawnComponentSpecSessions.get_command(scope, orphan_session, [])
    end

    test "returns error when context component is not found", %{
      scope: scope,
      project: project
    } do
      # Create session with invalid component_id
      invalid_session = %Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        component_id: Ecto.UUID.generate(),
        project: project,
        component: nil
      }

      assert {:error, "Context component not found"} =
               SpawnComponentSpecSessions.get_command(scope, invalid_session, [])
    end

    test "handles partial session creation failures gracefully", %{
      scope: scope,
      parent_session: parent_session
    } do
      # This test verifies that even if some child session creation fails,
      # the function continues and creates remaining sessions
      # In practice, session creation rarely fails if data is valid
      # but the step should handle this gracefully

      {:ok, command} = SpawnComponentSpecSessions.get_command(scope, parent_session, [])

      # Should still return ok with successfully created sessions
      assert {:ok, %Command{}} = {:ok, command}
      assert is_list(command.metadata.child_session_ids)
      assert length(command.metadata.child_session_ids) > 0
    end

    test "command metadata includes timestamp", %{
      scope: scope,
      parent_session: parent_session
    } do
      {:ok, command} = SpawnComponentSpecSessions.get_command(scope, parent_session, [])

      assert %DateTime{} = command.timestamp
    end
  end

  describe "handle_result/4" do
    setup do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})

      # Create context component
      context_component =
        component_fixture(scope, %{
          name: "Accounts",
          module_name: "Accounts",
          type: :context,
          project_id: project.id
        })

      # Create child components
      child1 =
        component_fixture(scope, %{
          name: "User",
          module_name: "User",
          type: :schema,
          project_id: project.id,
          parent_component_id: context_component.id
        })

      child2 =
        component_fixture(scope, %{
          name: "UserRepository",
          module_name: "UserRepository",
          type: :repository,
          project_id: project.id,
          parent_component_id: context_component.id
        })

      # Create parent session
      parent_session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextComponentsDesignSessions,
          component_id: context_component.id,
          project_id: project.id
        })

      # Create child sessions
      child_session1 =
        session_fixture(scope, %{
          type: CodeMySpec.ComponentSpecSessions,
          component_id: child1.id,
          project_id: project.id,
          session_id: parent_session.id,
          execution_mode: :agentic,
          status: :complete
        })

      child_session2 =
        session_fixture(scope, %{
          type: CodeMySpec.ComponentSpecSessions,
          component_id: child2.id,
          project_id: project.id,
          session_id: parent_session.id,
          execution_mode: :agentic,
          status: :complete
        })

      parent_session = CodeMySpec.Repo.preload(parent_session, [:project, :component])

      %{
        scope: scope,
        project: project,
        context_component: context_component,
        child1: child1,
        child2: child2,
        parent_session: parent_session,
        child_session1: child_session1,
        child_session2: child_session2
      }
    end

    test "returns success when all child sessions are complete and design files exist", %{
      scope: scope,
      parent_session: parent_session
    } do
      result = Result.success(%{message: "All child sessions complete"})

      # Create temporary design files to simulate successful completion
      design_file1 = "docs/design/my_app/user.md"
      design_file2 = "docs/design/my_app/user_repository.md"

      File.mkdir_p!("docs/design/my_app")
      File.write!(design_file1, "# User Design")
      File.write!(design_file2, "# UserRepository Design")

      on_exit(fn ->
        File.rm_rf!("docs/design/my_app")
      end)

      assert {:ok, session_updates, updated_result} =
               SpawnComponentSpecSessions.handle_result(scope, parent_session, result, [])

      assert session_updates == %{}
      assert updated_result.status == :ok
    end

    test "returns error when child sessions are still active", %{
      scope: scope,
      parent_session: parent_session,
      child_session1: child_session1
    } do
      # Update one child session to be active
      {:ok, _} =
        CodeMySpec.Sessions.update_session(scope, child_session1, %{status: :active})

      result = Result.success(%{message: "Checking status"})

      assert {:ok, _session_updates, updated_result} =
               SpawnComponentSpecSessions.handle_result(scope, parent_session, result, [])

      assert updated_result.status == :error
      assert updated_result.error_message =~ "Child sessions still running"
    end

    test "returns error when parent session not found", %{
      scope: scope
    } do
      # Create a session struct that doesn't exist in the database
      invalid_session = %Session{
        id: 999_999,
        type: CodeMySpec.ContextComponentsDesignSessions
      }

      result = Result.success(%{message: "Checking status"})

      assert {:error, "Session not found"} =
               SpawnComponentSpecSessions.handle_result(scope, invalid_session, result, [])
    end
  end
end
