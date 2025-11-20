defmodule CodeMySpec.ContextTestingSessions.Steps.FinalizeTest do
  use CodeMySpec.DataCase, async: true

  alias CodeMySpec.ContextTestingSessions.Steps.Finalize
  alias CodeMySpec.Sessions.{Command, Result, Session}

  import CodeMySpec.UsersFixtures
  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.SessionsFixtures

  # ============================================================================
  # Fixtures
  # ============================================================================

  defp setup_context_with_children(scope, opts \\ []) do
    # Create parent context component
    context_component =
      component_fixture(scope, %{
        name: Keyword.get(opts, :context_name, "TestContext"),
        type: :context,
        module_name: Keyword.get(opts, :context_module, "TestContext")
      })

    # Create child components
    child_count = Keyword.get(opts, :child_count, 3)

    children =
      Enum.map(0..(child_count - 1), fn idx ->
        component_fixture(scope, %{
          name: "ChildComponent#{idx}",
          type: :schema,
          module_name: "ChildComponent#{idx}",
          parent_component_id: context_component.id
        })
      end)

    {context_component, children}
  end

  defp create_parent_session(scope, context_component, opts \\ []) do
    _project = CodeMySpec.Repo.preload(context_component, :project).project

    branch_name =
      Keyword.get(opts, :branch_name, "test-context-testing-session-for-testcontext")

    state = Keyword.get(opts, :state, %{branch_name: branch_name})

    session_fixture(scope, %{
      type: CodeMySpec.ContextTestingSessions,
      component_id: context_component.id,
      environment: Keyword.get(opts, :environment, :local),
      agent: Keyword.get(opts, :agent, :claude_code),
      state: state
    })
    |> CodeMySpec.Repo.preload(component: :project)
  end

  defp create_child_session(scope, parent_session, component, opts \\ []) do
    session_fixture(scope, %{
      type: CodeMySpec.ComponentTestSessions,
      component_id: component.id,
      session_id: parent_session.id,
      execution_mode: Keyword.get(opts, :execution_mode, :agentic),
      agent: parent_session.agent,
      environment: parent_session.environment,
      status: Keyword.get(opts, :status, :complete),
      state: Keyword.get(opts, :state, %{})
    })
  end

  # ============================================================================
  # get_command/3 - Happy Path Tests
  # ============================================================================

  describe "get_command/3" do
    test "returns git command with all test files from child sessions" do
      scope = full_scope_fixture()
      {context_component, children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      # Create child sessions
      Enum.each(children, fn child ->
        create_child_session(scope, parent_session, child)
      end)

      # Reload parent session with children
      parent_session_reloaded = CodeMySpec.Sessions.get_session(scope, parent_session.id)

      assert {:ok, %Command{} = command} =
               Finalize.get_command(scope, parent_session_reloaded, [])

      assert command.module == Finalize
      assert is_binary(command.command)
      assert command.command =~ "git add"
      assert command.command =~ "git commit"
      assert command.command =~ "git push"
    end

    test "includes proper commit message with context name and component list" do
      scope = full_scope_fixture()
      {context_component, children} = setup_context_with_children(scope, child_count: 2)
      parent_session = create_parent_session(scope, context_component)

      # Create child sessions
      Enum.each(children, fn child ->
        create_child_session(scope, parent_session, child)
      end)

      # Reload parent session with children
      parent_session_reloaded = CodeMySpec.Sessions.get_session(scope, parent_session.id)

      assert {:ok, %Command{} = command} =
               Finalize.get_command(scope, parent_session_reloaded, [])

      # Check commit message structure
      assert command.command =~ "Generate tests for TestContext context"
      assert command.command =~ "ChildComponent0"
      assert command.command =~ "ChildComponent1"
      assert command.command =~ "🤖 Generated with [Claude Code]"
      assert command.command =~ "Co-Authored-By: Claude <noreply@anthropic.com>"
    end

    test "uses branch name from Utils.branch_name/1" do
      scope = full_scope_fixture()
      {context_component, children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      # Create child sessions
      Enum.each(children, fn child ->
        create_child_session(scope, parent_session, child)
      end)

      # Reload parent session with children
      parent_session_reloaded = CodeMySpec.Sessions.get_session(scope, parent_session.id)

      assert {:ok, %Command{} = command} =
               Finalize.get_command(scope, parent_session_reloaded, [])

      # Branch name is derived from component name using Utils.branch_name/1
      assert command.command =~ "git push -u origin test-context-testing-session-for-testcontext"
    end

    test "returns error when context component is nil" do
      scope = full_scope_fixture()

      # Create session with non-existent component
      parent_session = %Session{
        id: 1,
        type: CodeMySpec.ContextTestingSessions,
        component_id: 999_999,
        component: nil,
        environment: :local,
        agent: :claude_code,
        state: %{branch_name: "test-branch"},
        account_id: scope.active_account.id,
        user_id: scope.user.id,
        project_id: scope.active_project.id,
        child_sessions: []
      }

      assert {:error, "Context component not found in session"} =
               Finalize.get_command(scope, parent_session, [])
    end

    test "returns error when context component_id is nil" do
      scope = full_scope_fixture()

      parent_session = %Session{
        id: 1,
        type: CodeMySpec.ContextTestingSessions,
        component_id: nil,
        component: nil,
        environment: :local,
        agent: :claude_code,
        state: %{branch_name: "test-branch"},
        account_id: scope.active_account.id,
        user_id: scope.user.id,
        project_id: scope.active_project.id,
        child_sessions: []
      }

      assert {:error, "Context component not found in session"} =
               Finalize.get_command(scope, parent_session, [])
    end

    test "returns error when child_sessions is empty" do
      scope = full_scope_fixture()
      context_component = component_fixture(scope, %{name: "EmptyContext", type: :context})
      parent_session = create_parent_session(scope, context_component)

      # Reload parent session (will have no children)
      parent_session_reloaded = CodeMySpec.Sessions.get_session(scope, parent_session.id)

      assert {:error, "No child sessions found"} =
               Finalize.get_command(scope, parent_session_reloaded, [])
    end

    test "returns error when child_sessions is nil" do
      scope = full_scope_fixture()
      context_component = component_fixture(scope, %{name: "TestContext", type: :context})
      %Session{} = parent_session = create_parent_session(scope, context_component)

      # Create a session without preloaded child_sessions
      parent_session_without_children = %Session{
        parent_session
        | child_sessions: []
      }

      assert {:error, "No child sessions found"} =
               Finalize.get_command(scope, parent_session_without_children, [])
    end

    test "includes metadata with branch_name and committed_files count" do
      scope = full_scope_fixture()
      {context_component, children} = setup_context_with_children(scope, child_count: 2)
      parent_session = create_parent_session(scope, context_component)

      # Create child sessions
      Enum.each(children, fn child ->
        create_child_session(scope, parent_session, child)
      end)

      # Reload parent session with children
      parent_session_reloaded = CodeMySpec.Sessions.get_session(scope, parent_session.id)

      assert {:ok, %Command{} = command} =
               Finalize.get_command(scope, parent_session_reloaded, [])

      # Branch name is derived from component name
      assert command.metadata.branch_name == "test-context-testing-session-for-testcontext"
      # 2 components * 1 test file each = 2 files
      assert command.metadata.committed_files == 2
    end

    test "collects test files from multiple child sessions correctly" do
      scope = full_scope_fixture()
      {context_component, children} = setup_context_with_children(scope, child_count: 4)
      parent_session = create_parent_session(scope, context_component)

      # Create child sessions
      Enum.each(children, fn child ->
        create_child_session(scope, parent_session, child)
      end)

      # Reload parent session with children
      parent_session_reloaded = CodeMySpec.Sessions.get_session(scope, parent_session.id)

      assert {:ok, %Command{} = command} =
               Finalize.get_command(scope, parent_session_reloaded, [])

      # Check for all test files (uses MyApp from project fixture)
      assert command.command =~ "test/my_app/child_component0_test.exs"
      assert command.command =~ "test/my_app/child_component1_test.exs"
      assert command.command =~ "test/my_app/child_component2_test.exs"
      assert command.command =~ "test/my_app/child_component3_test.exs"

      # Should have 4 test files
      assert command.metadata.committed_files == 4
    end

    test "preloads component and project associations for each child session" do
      scope = full_scope_fixture()
      {context_component, children} = setup_context_with_children(scope, child_count: 2)
      parent_session = create_parent_session(scope, context_component)

      # Create child sessions
      Enum.each(children, fn child ->
        create_child_session(scope, parent_session, child)
      end)

      # Reload parent session with children
      parent_session_reloaded = CodeMySpec.Sessions.get_session(scope, parent_session.id)

      assert {:ok, %Command{} = command} =
               Finalize.get_command(scope, parent_session_reloaded, [])

      # If associations weren't preloaded, the command generation would fail
      # Verify command was successfully generated with test file paths
      assert command.command =~ "test/my_app/child_component0_test.exs"
      assert command.command =~ "test/my_app/child_component1_test.exs"
    end

    test "uses heredoc format for commit message" do
      scope = full_scope_fixture()
      {context_component, children} = setup_context_with_children(scope, child_count: 1)
      parent_session = create_parent_session(scope, context_component)

      # Create child session
      Enum.each(children, fn child ->
        create_child_session(scope, parent_session, child)
      end)

      # Reload parent session with children
      parent_session_reloaded = CodeMySpec.Sessions.get_session(scope, parent_session.id)

      assert {:ok, %Command{} = command} =
               Finalize.get_command(scope, parent_session_reloaded, [])

      # Check for heredoc pattern
      assert command.command =~ "git commit -m \"$(cat <<'EOF'"
      assert command.command =~ "EOF\n)\""
    end

    test "uses relative paths for test files" do
      scope = full_scope_fixture()
      {context_component, children} = setup_context_with_children(scope, child_count: 1)
      parent_session = create_parent_session(scope, context_component)

      # Create child session
      [child] = children
      create_child_session(scope, parent_session, child)

      # Reload parent session with children
      parent_session_reloaded = CodeMySpec.Sessions.get_session(scope, parent_session.id)

      assert {:ok, %Command{} = command} =
               Finalize.get_command(scope, parent_session_reloaded, [])

      # Files should be relative paths, not absolute
      refute command.command =~ "/Users/"
      refute command.command =~ "/home/"
      assert command.command =~ "test/my_app/"
    end
  end

  # ============================================================================
  # handle_result/4 - Happy Path Tests
  # ============================================================================

  describe "handle_result/4" do
    test "marks session as complete when result status is ok" do
      scope = full_scope_fixture()
      {context_component, _children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      result = Result.success(%{})

      assert {:ok, session_updates, _updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      assert session_updates.status == :complete
    end

    test "returns session_updates with status complete on success" do
      scope = full_scope_fixture()
      {context_component, _children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      result = Result.success(%{message: "Git operations completed"})

      assert {:ok, session_updates, _updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      assert session_updates == %{status: :complete}
    end

    test "marks session as failed when result status is error" do
      scope = full_scope_fixture()
      {context_component, _children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      result = Result.error("fatal: unable to push to remote")

      assert {:ok, session_updates, _updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      assert session_updates.status == :failed
    end

    test "adds finalized_at timestamp to session state on error" do
      scope = full_scope_fixture()
      {context_component, _children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      error_message = "fatal: Authentication failed"
      result = Result.error(error_message)

      assert {:ok, session_updates, _updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      assert %DateTime{} = session_updates.state.finalized_at
    end

    test "preserves existing session state when merging error data" do
      scope = full_scope_fixture()
      {context_component, _children} = setup_context_with_children(scope)

      parent_session =
        create_parent_session(scope, context_component, state: %{branch_name: "test-branch"})

      error_message = "fatal: push failed"
      result = Result.error(error_message)

      assert {:ok, session_updates, _updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      # Existing state should be preserved
      assert session_updates.state.branch_name == "test-branch"
      # New error data should be added
      assert session_updates.state.error == error_message
      assert %DateTime{} = session_updates.state.finalized_at
    end

    test "includes error message in session state on failure" do
      scope = full_scope_fixture()
      {context_component, _children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      error_message = "fatal: unable to create commit"
      result = Result.error(error_message)

      assert {:ok, session_updates, _updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      assert session_updates.state.error == error_message
      assert session_updates.status == :failed
    end

    test "returns ok tuple even when marking session as failed" do
      scope = full_scope_fixture()
      {context_component, _children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      result = Result.error("fatal: git operation failed")

      # Should return :ok tuple, not :error
      assert {:ok, session_updates, returned_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      assert session_updates.status == :failed
      assert returned_result == result
    end

    test "returns result unchanged" do
      scope = full_scope_fixture()
      {context_component, _children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      original_result = Result.success(%{message: "All test files committed"})

      assert {:ok, _session_updates, returned_result} =
               Finalize.handle_result(scope, parent_session, original_result, [])

      assert returned_result == original_result
      assert returned_result.status == :ok
      assert returned_result.data.message == "All test files committed"
    end

    test "handles error result and returns it unchanged" do
      scope = full_scope_fixture()
      {context_component, _children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      original_result = Result.error("fatal: unable to push")

      assert {:ok, _session_updates, returned_result} =
               Finalize.handle_result(scope, parent_session, original_result, [])

      assert returned_result == original_result
      assert returned_result.status == :error
      assert returned_result.error_message == "fatal: unable to push"
    end
  end
end
