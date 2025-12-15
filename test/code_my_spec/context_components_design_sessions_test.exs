defmodule CodeMySpec.ContextComponentsDesignSessionsTest do
  use CodeMySpec.DataCase
  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures}
  alias CodeMySpec.{Sessions, Components}
  alias CodeMySpec.ContextComponentsDesignSessions

  alias CodeMySpec.ContextComponentsDesignSessions.Steps.{
    Initialize,
    SpawnComponentDesignSessions,
    SpawnReviewSession,
    Finalize
  }

  describe "context components design session workflow" do
    setup do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account)

      project =
        user_scope_fixture(user, account)
        |> project_fixture(%{account_id: account.id, module_name: "MyApp"})

      scope = user_scope_fixture(user, account, project)

      # Create test context component
      {:ok, accounts_context} =
        Components.create_component(scope, %{
          name: "Accounts",
          type: :context,
          module_name: "MyApp.Accounts",
          description: "Accounts context for managing users and authentication"
        })

      # Create child components
      {:ok, user_schema} =
        Components.create_component(scope, %{
          name: "User",
          type: :schema,
          module_name: "MyApp.Accounts.User",
          description: "User schema",
          parent_component_id: accounts_context.id,
          priority: 10
        })

      {:ok, user_repository} =
        Components.create_component(scope, %{
          name: "UserRepository",
          type: :repository,
          module_name: "MyApp.Accounts.UserRepository",
          description: "Repository for user persistence",
          parent_component_id: accounts_context.id,
          priority: 5
        })

      {:ok, accounts_live} =
        Components.create_component(scope, %{
          name: "AccountsLive",
          type: :other,
          module_name: "MyApp.AccountsLive",
          description: "LiveView for accounts management",
          parent_component_id: accounts_context.id,
          priority: 1
        })

      %{
        scope: scope,
        project: project,
        accounts_context: accounts_context,
        user_schema: user_schema,
        user_repository: user_repository,
        accounts_live: accounts_live
      }
    end

    @tag timeout: 300_000
    test "executes complete context components design workflow", %{
      scope: scope,
      accounts_context: accounts_context
    } do
      Sessions.subscribe_sessions(scope)

      # Create context components design session
      {:ok, session} =
        Sessions.create_session(scope, %{
          type: ContextComponentsDesignSessions,
          agent: :claude_code,
          environment: :local,
          component_id: accounts_context.id
        })

      assert_received {:created, %Sessions.Session{}}

      # Step 1: Initialize
      {:ok, session} = Sessions.next_command(scope, session.id)
      [interaction | _] = session.interactions
      assert interaction.command.module == Initialize

      # Mock git branch creation
      result = %{status: :ok, stdout: "Created branch", stderr: "", exit_code: 0}

      {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, result)
      assert_received {:updated, %Sessions.Session{}}

      [last_interaction | _] = session.interactions
      assert last_interaction.result.status == :ok

      # Step 2: SpawnComponentDesignSessions
      {:ok, session} = Sessions.next_command(scope, session.id)
      [interaction | _] = session.interactions
      assert interaction.command.module == SpawnComponentDesignSessions
      assert interaction.command.command == "spawn_sessions"
      assert is_list(interaction.command.metadata["child_session_ids"])
      assert length(interaction.command.metadata["child_session_ids"]) == 3

      # Store child session IDs for later
      child_session_ids = interaction.command.metadata["child_session_ids"]

      # Mock successful completion of child sessions
      result = %{status: :ok, stdout: "All child sessions started", stderr: "", exit_code: 0}

      # Mark all child sessions as complete and create design files
      for child_id <- child_session_ids do
        child_session = Sessions.get_session!(scope, child_id)
        {:ok, _} = Sessions.update_session(scope, child_session, %{status: :complete})
      end

      # Create design files
      File.mkdir_p!("docs/design/my_app")
      File.write!("docs/design/my_app/user.md", "# User Design")
      File.write!("docs/design/my_app/user_repository.md", "# UserRepository Design")
      File.write!("docs/design/my_app/accounts_live.md", "# AccountsLive Design")

      {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, result)
      assert_received {:updated, %Sessions.Session{}}

      [last_interaction | _] = session.interactions
      assert last_interaction.result.status == :ok

      # Step 3: SpawnReviewSession
      {:ok, session} = Sessions.next_command(scope, session.id)
      [interaction | _] = session.interactions
      assert interaction.command.module == SpawnReviewSession
      assert interaction.command.command == "spawn_sessions"
      assert is_list(interaction.command.metadata["child_session_ids"])
      assert length(interaction.command.metadata["child_session_ids"]) == 1

      # Get the review session
      [review_session_id] = interaction.command.metadata["child_session_ids"]
      review_session = Sessions.get_session!(scope, review_session_id)

      # Mock successful completion of review session
      result = %{status: :ok, stdout: "Review session started", stderr: "", exit_code: 0}

      # Mark review session as complete and create review file
      {:ok, _} = Sessions.update_session(scope, review_session, %{status: :complete})

      File.mkdir_p!("docs/review")

      File.write!(
        "docs/review/accounts_components_review.md",
        "# Accounts Components Review"
      )

      {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, result)
      assert_received {:updated, %Sessions.Session{}}

      [last_interaction | _] = session.interactions
      assert last_interaction.result.status == :ok

      # Step 4: Finalize
      {:ok, session} = Sessions.next_command(scope, session.id)
      [interaction | _] = session.interactions
      assert interaction.command.module == Finalize

      # Mock successful PR creation
      pr_url = "https://github.com/example/repo/pull/123"

      result = %{
        status: :ok,
        stdout: pr_url,
        stderr: "",
        exit_code: 0
      }

      {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, result)
      assert_received {:updated, %Sessions.Session{}}

      [last_interaction | _] = session.interactions
      assert last_interaction.result.status == :ok
      assert session.status == :complete
      assert session.state["pr_url"] == pr_url
      assert session.state["finalized_at"]

      # Session should be complete
      assert {:error, :complete} = Sessions.next_command(scope, session.id)

      # Cleanup
      File.rm_rf!("docs/design/my_app")
      File.rm_rf!("docs/review")
    end

    @tag timeout: 300_000
    test "handles validation failure and retry for child sessions", %{
      scope: scope,
      accounts_context: accounts_context
    } do
      Sessions.subscribe_sessions(scope)

      # Create session
      {:ok, session} =
        Sessions.create_session(scope, %{
          type: ContextComponentsDesignSessions,
          agent: :claude_code,
          environment: :local,
          component_id: accounts_context.id
        })

      # Step 1: Initialize
      {:ok, session} = Sessions.next_command(scope, session.id)
      [interaction | _] = session.interactions
      result = %{status: :ok, stdout: "Created branch", stderr: "", exit_code: 0}
      {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, result)

      # Step 2: SpawnComponentDesignSessions - first attempt
      {:ok, session} = Sessions.next_command(scope, session.id)
      [interaction | _] = session.interactions
      child_session_ids = interaction.command.metadata["child_session_ids"]

      # Mark only some child sessions complete (validation should fail)
      [first_child_id | _] = child_session_ids
      child_session = Sessions.get_session!(scope, first_child_id)
      {:ok, _} = Sessions.update_session(scope, child_session, %{status: :complete})

      # Create only one design file
      File.mkdir_p!("docs/design/my_app")
      File.write!("docs/design/my_app/user.md", "# User Design")

      result = %{status: :ok, stdout: "Sessions started", stderr: "", exit_code: 0}
      {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, result)

      [last_interaction | _] = session.interactions
      # Should return error due to validation failure
      assert last_interaction.result.status == :error

      # Step 3: Should retry SpawnComponentDesignSessions
      {:ok, session} = Sessions.next_command(scope, session.id)
      [interaction | _] = session.interactions
      assert interaction.command.module == SpawnComponentDesignSessions

      # The retry should return the SAME child session IDs (not create new ones)
      retry_child_session_ids = interaction.command.metadata["child_session_ids"]
      assert Enum.sort(retry_child_session_ids) == Enum.sort(child_session_ids)

      # Now complete all child sessions and create all files
      for child_id <- child_session_ids do
        child_session = Sessions.get_session!(scope, child_id)
        {:ok, _} = Sessions.update_session(scope, child_session, %{status: :complete})
      end

      File.write!("docs/design/my_app/user_repository.md", "# UserRepository Design")
      File.write!("docs/design/my_app/accounts_live.md", "# AccountsLive Design")

      result = %{status: :ok, stdout: "All sessions complete", stderr: "", exit_code: 0}
      {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, result)

      [last_interaction | _] = session.interactions
      # Should now succeed
      assert last_interaction.result.status == :ok

      # Should proceed to next step
      {:ok, session} = Sessions.next_command(scope, session.id)
      [interaction | _] = session.interactions
      assert interaction.command.module == SpawnReviewSession

      # Cleanup
      File.rm_rf!("docs/design/my_app")
    end

    @tag timeout: 300_000
    test "handles validation failure and retry for review session", %{
      scope: scope,
      accounts_context: accounts_context
    } do
      Sessions.subscribe_sessions(scope)

      # Create session and complete through SpawnComponentDesignSessions
      {:ok, session} =
        Sessions.create_session(scope, %{
          type: ContextComponentsDesignSessions,
          agent: :claude_code,
          environment: :local,
          component_id: accounts_context.id
        })

      # Initialize
      {:ok, session} = Sessions.next_command(scope, session.id)
      [interaction | _] = session.interactions
      result = %{status: :ok, stdout: "Created branch", stderr: "", exit_code: 0}
      {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, result)

      # SpawnComponentDesignSessions - complete successfully
      {:ok, session} = Sessions.next_command(scope, session.id)
      [interaction | _] = session.interactions
      child_session_ids = interaction.command.metadata["child_session_ids"]

      for child_id <- child_session_ids do
        child_session = Sessions.get_session!(scope, child_id)
        {:ok, _} = Sessions.update_session(scope, child_session, %{status: :complete})
      end

      File.mkdir_p!("docs/design/my_app")
      File.write!("docs/design/my_app/user.md", "# User Design")
      File.write!("docs/design/my_app/user_repository.md", "# UserRepository Design")
      File.write!("docs/design/my_app/accounts_live.md", "# AccountsLive Design")

      result = %{status: :ok, stdout: "Sessions complete", stderr: "", exit_code: 0}
      {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, result)

      # SpawnReviewSession - first attempt (leave review incomplete)
      {:ok, session} = Sessions.next_command(scope, session.id)
      [interaction | _] = session.interactions
      [review_session_id] = interaction.command.metadata["child_session_ids"]
      review_session = Sessions.get_session!(scope, review_session_id)

      # Don't mark review session as complete and don't create review file
      result = %{status: :ok, stdout: "Review started", stderr: "", exit_code: 0}
      {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, result)

      [last_interaction | _] = session.interactions
      # Should fail validation
      assert last_interaction.result.status == :error

      # Should retry SpawnReviewSession
      {:ok, session} = Sessions.next_command(scope, session.id)
      [interaction | _] = session.interactions
      assert interaction.command.module == SpawnReviewSession

      # The retry should return the SAME review session ID (not create a new one)
      [retry_review_session_id] = interaction.command.metadata["child_session_ids"]
      assert retry_review_session_id == review_session_id

      # Now complete review session and create review file
      {:ok, _} = Sessions.update_session(scope, review_session, %{status: :complete})

      File.mkdir_p!("docs/review")

      File.write!(
        "docs/review/accounts_components_review.md",
        "# Accounts Components Review"
      )

      result = %{status: :ok, stdout: "Review complete", stderr: "", exit_code: 0}
      {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, result)

      [last_interaction | _] = session.interactions
      # Should now succeed
      assert last_interaction.result.status == :ok

      # Should proceed to Finalize
      {:ok, session} = Sessions.next_command(scope, session.id)
      [interaction | _] = session.interactions
      assert interaction.command.module == Finalize

      # Cleanup
      File.rm_rf!("docs/design/my_app")
      File.rm_rf!("docs/review")
    end
  end
end
