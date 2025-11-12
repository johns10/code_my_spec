defmodule CodeMySpec.ContextCodingSessions.Steps.FinalizeTest do
  use CodeMySpec.DataCase, async: true

  alias CodeMySpec.ContextCodingSessions.Steps.Finalize
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

    branch_name = Keyword.get(opts, :branch_name, "code-context-coding-session-for-testcontext")
    state = Keyword.get(opts, :state, %{branch_name: branch_name})

    session_fixture(scope, %{
      type: CodeMySpec.ContextCodingSessions,
      component_id: context_component.id,
      environment: Keyword.get(opts, :environment, :local),
      agent: Keyword.get(opts, :agent, :claude_code),
      state: state
    })
    |> CodeMySpec.Repo.preload(component: :project)
  end

  defp create_child_session(scope, parent_session, component, opts \\ []) do
    session_fixture(scope, %{
      type: CodeMySpec.ComponentCodingSessions,
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
    test "returns git command with all child component files when child sessions exist" do
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

    test "includes code files and test files from all child components" do
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

      # Check for code files (uses MyApp from project fixture)
      assert command.command =~ "lib/my_app/child_component0.ex"
      assert command.command =~ "lib/my_app/child_component1.ex"

      # Check for test files
      assert command.command =~ "test/my_app/child_component0_test.exs"
      assert command.command =~ "test/my_app/child_component1_test.exs"
    end

    test "generates proper commit message with context name and component list" do
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
      assert command.command =~ "Implement TestContext context"
      assert command.command =~ "ChildComponent0"
      assert command.command =~ "ChildComponent1"
      assert command.command =~ "🤖 Generated with [Claude Code]"
      assert command.command =~ "Co-Authored-By: Claude <noreply@anthropic.com>"
    end

    test "includes git push command with branch name derived from component" do
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

      # Branch name is derived from component name
      assert command.command =~ "git push -u origin code-context-coding-session-for-testcontext"
    end

    test "uses relative paths for files" do
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
      assert command.command =~ "lib/my_app/"
      assert command.command =~ "test/my_app/"
    end

    test "command metadata includes branch name and file count" do
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
      assert command.metadata.branch_name == "code-context-coding-session-for-testcontext"
      # 2 components * 2 files each (code + test) = 4 files
      assert command.metadata.committed_files == 4
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

    # ============================================================================
    # get_command/3 - Error Cases
    # ============================================================================

    test "derives branch name from component when state is empty" do
      scope = full_scope_fixture()
      {context_component, children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component, state: %{})

      # Create child sessions
      Enum.each(children, fn child ->
        create_child_session(scope, parent_session, child)
      end)

      # Reload parent session with children
      parent_session_reloaded = CodeMySpec.Sessions.get_session(scope, parent_session.id)

      assert {:ok, %Command{} = command} =
               Finalize.get_command(scope, parent_session_reloaded, [])

      # Branch name is always derived from component, regardless of state
      assert command.command =~ "git push -u origin code-context-coding-session-for-testcontext"
    end

    test "returns error when context component not found" do
      scope = full_scope_fixture()

      # Create session with non-existent component_id
      parent_session = %Session{
        id: 1,
        type: CodeMySpec.ContextCodingSessions,
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

    test "returns error when no child sessions exist" do
      scope = full_scope_fixture()
      context_component = component_fixture(scope, %{name: "EmptyContext", type: :context})
      parent_session = create_parent_session(scope, context_component)

      # Reload parent session (will have no children)
      parent_session_reloaded = CodeMySpec.Sessions.get_session(scope, parent_session.id)

      assert {:error, "No child sessions found"} =
               Finalize.get_command(scope, parent_session_reloaded, [])
    end

    test "returns error when session.component_id is nil" do
      scope = full_scope_fixture()

      parent_session = %Session{
        id: 1,
        type: CodeMySpec.ContextCodingSessions,
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

    test "generates correct command with multiple child components" do
      scope = full_scope_fixture()
      {context_component, children} = setup_context_with_children(scope, child_count: 5)
      parent_session = create_parent_session(scope, context_component)

      # Create child sessions
      Enum.each(children, fn child ->
        create_child_session(scope, parent_session, child)
      end)

      # Reload parent session with children
      parent_session_reloaded = CodeMySpec.Sessions.get_session(scope, parent_session.id)

      assert {:ok, %Command{} = command} =
               Finalize.get_command(scope, parent_session_reloaded, [])

      # Should include all 5 components in commit message
      assert command.command =~ "ChildComponent0"
      assert command.command =~ "ChildComponent1"
      assert command.command =~ "ChildComponent2"
      assert command.command =~ "ChildComponent3"
      assert command.command =~ "ChildComponent4"

      # Metadata should show 10 files (5 * 2)
      assert command.metadata.committed_files == 10
    end
  end

  # ============================================================================
  # handle_result/4 - Happy Path Tests
  # ============================================================================

  describe "handle_result/4" do
    test "marks session as complete when git operations succeed" do
      scope = full_scope_fixture()
      {context_component, _children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      result = Result.success(%{})

      assert {:ok, session_updates, _updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      assert session_updates.status == :complete
    end

    test "returns updated result unchanged" do
      scope = full_scope_fixture()
      {context_component, _children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      original_result = Result.success(%{message: "Git operations completed"})

      assert {:ok, _session_updates, returned_result} =
               Finalize.handle_result(scope, parent_session, original_result, [])

      assert returned_result == original_result
      assert returned_result.status == :ok
      assert returned_result.data.message == "Git operations completed"
    end

    # ============================================================================
    # handle_result/4 - Error Cases
    # ============================================================================

    test "marks session as failed when git add fails" do
      scope = full_scope_fixture()
      {context_component, _children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      result = Result.error("fatal: pathspec 'lib/missing.ex' did not match any files")

      assert {:ok, session_updates, _updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      assert session_updates.status == :failed
    end

    test "marks session as failed when git commit fails" do
      scope = full_scope_fixture()
      {context_component, _children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      result = Result.error("fatal: unable to create commit")

      assert {:ok, session_updates, _updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      assert session_updates.status == :failed
    end

    test "marks session as failed when git push fails" do
      scope = full_scope_fixture()
      {context_component, _children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      result = Result.error("error: failed to push some refs to 'origin'")

      assert {:ok, session_updates, _updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      assert session_updates.status == :failed
    end

    test "includes error details in session state when operations fail" do
      scope = full_scope_fixture()
      {context_component, _children} = setup_context_with_children(scope)
      parent_session = create_parent_session(scope, context_component)

      error_message = "fatal: Authentication failed"
      result = Result.error(error_message)

      assert {:ok, session_updates, _updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      assert session_updates.state.error == error_message
      assert %DateTime{} = session_updates.state.finalized_at
    end
  end
end
