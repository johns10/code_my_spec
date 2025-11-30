defmodule CodeMySpec.ContextComponentsDesignSessions.Steps.SpawnReviewSessionTest do
  use CodeMySpec.DataCase, async: true

  alias CodeMySpec.ContextComponentsDesignSessions.Steps.SpawnReviewSession
  alias CodeMySpec.Sessions.{Command, Result, Session}
  alias CodeMySpec.Sessions

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
        parent_session: parent_session
      }
    end

    test "returns spawn_sessions command with child_session_ids in metadata", %{
      scope: scope,
      parent_session: parent_session
    } do
      assert {:ok, %Command{} = command} =
               SpawnReviewSession.get_command(scope, parent_session, [])

      assert command.module == SpawnReviewSession
      assert command.command == "spawn_sessions"
      assert is_map(command.metadata)
      assert is_list(command.metadata.child_session_ids)
      assert [review_session_id] = command.metadata.child_session_ids
      assert is_integer(review_session_id)
      assert command.metadata.session_type == :component_design_review
    end

    test "creates review session with correct attributes", %{
      scope: scope,
      parent_session: parent_session
    } do
      {:ok, command} = SpawnReviewSession.get_command(scope, parent_session, [])

      # Fetch created review session
      [review_session_id] = command.metadata.child_session_ids
      review_session = Sessions.get_session!(scope, review_session_id)

      assert review_session.type == CodeMySpec.ComponentDesignReviewSessions
      assert review_session.session_id == parent_session.id
      assert review_session.component_id == parent_session.component_id
      assert review_session.execution_mode == :agentic
      assert review_session.agent == :claude_code
      assert review_session.environment == :local
      assert review_session.status == :active
      assert review_session.account_id == scope.active_account.id
      assert review_session.project_id == scope.active_project.id
      assert review_session.user_id == scope.user.id
    end

    test "command metadata includes timestamp", %{
      scope: scope,
      parent_session: parent_session
    } do
      {:ok, command} = SpawnReviewSession.get_command(scope, parent_session, [])

      assert %DateTime{} = command.timestamp
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
        component: nil,
        agent: :claude_code,
        environment: :local
      }

      assert {:error, "Context component not found"} =
               SpawnReviewSession.get_command(scope, invalid_session, [])
    end

    test "returns error when session has no component_id", %{
      scope: scope,
      project: project
    } do
      invalid_session = %Session{
        type: CodeMySpec.ContextComponentsDesignSessions,
        component_id: nil,
        project: project,
        component: nil,
        agent: :claude_code,
        environment: :local
      }

      assert {:error, error_message} = SpawnReviewSession.get_command(scope, invalid_session, [])
      assert error_message =~ "Context component not found"
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

      # Create parent session
      parent_session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextComponentsDesignSessions,
          component_id: context_component.id,
          project_id: project.id
        })

      # Create review session (simulating spawned review session)
      review_session =
        session_fixture(scope, %{
          type: CodeMySpec.ComponentDesignReviewSessions,
          component_id: context_component.id,
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
        parent_session: parent_session,
        review_session: review_session
      }
    end

    test "returns success when review session is complete", %{
      scope: scope,
      parent_session: parent_session,
      review_session: review_session
    } do
      # Create command with child_session_ids
      command = %Command{
        module: SpawnReviewSession,
        command: "spawn_sessions",
        metadata: %{
          child_session_ids: [review_session.id],
          session_type: :component_design_review
        },
        timestamp: DateTime.utc_now()
      }

      # Add the command to the session's interactions
      interaction = CodeMySpec.Sessions.Interaction.new_with_command(command)
      parent_session_with_interaction = %{parent_session | interactions: [interaction]}

      result = Result.success(%{message: "Review session complete"})

      assert {:ok, session_updates, updated_result} =
               SpawnReviewSession.handle_result(scope, parent_session_with_interaction, result,
                 command: command
               )

      assert session_updates == %{}
      assert updated_result.status == :ok
    end

    test "returns error when review session is still active", %{
      scope: scope,
      parent_session: parent_session,
      review_session: review_session
    } do
      # Update review session to be active
      {:ok, _} = Sessions.update_session(scope, review_session, %{status: :active})

      command = %Command{
        module: SpawnReviewSession,
        command: "spawn_sessions",
        metadata: %{
          child_session_ids: [review_session.id],
          session_type: :component_design_review
        },
        timestamp: DateTime.utc_now()
      }

      # Add the command to the session's interactions
      interaction = CodeMySpec.Sessions.Interaction.new_with_command(command)
      parent_session_with_interaction = %{parent_session | interactions: [interaction]}

      result = Result.success(%{message: "Checking status"})

      assert {:ok, _session_updates, updated_result} =
               SpawnReviewSession.handle_result(scope, parent_session_with_interaction, result,
                 command: command
               )

      assert updated_result.status == :error
      assert updated_result.error_message =~ "Review session still"
    end

    test "returns error when review session failed", %{
      scope: scope,
      parent_session: parent_session,
      review_session: review_session
    } do
      # Update review session to failed status
      {:ok, _} = Sessions.update_session(scope, review_session, %{status: :failed})

      command = %Command{
        module: SpawnReviewSession,
        command: "spawn_sessions",
        metadata: %{
          child_session_ids: [review_session.id],
          session_type: :component_design_review
        },
        timestamp: DateTime.utc_now()
      }

      # Add the command to the session's interactions
      interaction = CodeMySpec.Sessions.Interaction.new_with_command(command)
      parent_session_with_interaction = %{parent_session | interactions: [interaction]}

      result = Result.success(%{message: "Checking status"})

      assert {:ok, _session_updates, updated_result} =
               SpawnReviewSession.handle_result(scope, parent_session_with_interaction, result,
                 command: command
               )

      assert updated_result.status == :error
      assert updated_result.error_message =~ "failed"
    end

    test "returns error when review session cancelled", %{
      scope: scope,
      parent_session: parent_session,
      review_session: review_session
    } do
      # Update review session to cancelled status
      {:ok, _} = Sessions.update_session(scope, review_session, %{status: :cancelled})

      command = %Command{
        module: SpawnReviewSession,
        command: "spawn_sessions",
        metadata: %{
          child_session_ids: [review_session.id],
          session_type: :component_design_review
        },
        timestamp: DateTime.utc_now()
      }

      # Add the command to the session's interactions
      interaction = CodeMySpec.Sessions.Interaction.new_with_command(command)
      parent_session_with_interaction = %{parent_session | interactions: [interaction]}

      result = Result.success(%{message: "Checking status"})

      assert {:ok, _session_updates, updated_result} =
               SpawnReviewSession.handle_result(scope, parent_session_with_interaction, result,
                 command: command
               )

      assert updated_result.status == :error
      assert updated_result.error_message =~ "cancelled"
    end

    test "returns error when review session not found", %{
      scope: scope,
      parent_session: parent_session
    } do
      # Create command with invalid child_session_id
      command = %Command{
        module: SpawnReviewSession,
        command: "spawn_sessions",
        metadata: %{
          child_session_ids: [999_999],
          session_type: :component_design_review
        },
        timestamp: DateTime.utc_now()
      }

      # Add the command to the session's interactions
      interaction = CodeMySpec.Sessions.Interaction.new_with_command(command)
      parent_session_with_interaction = %{parent_session | interactions: [interaction]}

      result = Result.success(%{message: "Checking status"})

      assert {:error, "Review session not found"} =
               SpawnReviewSession.handle_result(scope, parent_session_with_interaction, result,
                 command: command
               )
    end

    test "returns error when command metadata is missing child_session_ids", %{
      scope: scope,
      parent_session: parent_session
    } do
      # Create command without child_session_ids
      command = %Command{
        module: SpawnReviewSession,
        command: "spawn_sessions",
        metadata: %{session_type: :component_design_review},
        timestamp: DateTime.utc_now()
      }

      # Add the command to the session's interactions
      interaction = CodeMySpec.Sessions.Interaction.new_with_command(command)
      parent_session_with_interaction = %{parent_session | interactions: [interaction]}

      result = Result.success(%{message: "Checking status"})

      assert {:error, error_message} =
               SpawnReviewSession.handle_result(scope, parent_session_with_interaction, result,
                 command: command
               )

      assert error_message =~ "child_session_ids"
    end

    test "preserves original result data when validation succeeds", %{
      scope: scope,
      parent_session: parent_session,
      review_session: review_session
    } do
      command = %Command{
        module: SpawnReviewSession,
        command: "spawn_sessions",
        metadata: %{
          child_session_ids: [review_session.id],
          session_type: :component_design_review
        },
        timestamp: DateTime.utc_now()
      }

      # Add the command to the session's interactions
      interaction = CodeMySpec.Sessions.Interaction.new_with_command(command)
      parent_session_with_interaction = %{parent_session | interactions: [interaction]}

      original_data = %{message: "Review complete", extra_field: "preserved"}
      result = Result.success(original_data)

      assert {:ok, _session_updates, updated_result} =
               SpawnReviewSession.handle_result(scope, parent_session_with_interaction, result,
                 command: command
               )

      assert updated_result.status == :ok
      assert updated_result.data.message == "Review complete"
      assert updated_result.data.extra_field == "preserved"
    end
  end
end
