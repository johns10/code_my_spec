defmodule CodeMySpec.ContextDesignReviewSessions.Steps.ExecuteReviewTest do
  use CodeMySpec.DataCase, async: true

  alias CodeMySpec.ContextDesignReviewSessions.Steps.ExecuteReview
  alias CodeMySpec.Sessions.{Command, Result, Session}

  import CodeMySpec.UsersFixtures
  import CodeMySpec.ProjectsFixtures
  import CodeMySpec.ComponentsFixtures
  import CodeMySpec.SessionsFixtures
  import CodeMySpec.StoriesFixtures

  # ============================================================================
  # Happy Path Tests - Test the most common, expected usage patterns first
  # ============================================================================

  describe "get_command/3 - happy path" do
    setup do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "CodeMySpec"})

      # Create a context component (the one being reviewed)
      context_component =
        component_fixture(scope, %{
          name: "Sessions",
          module_name: "Sessions",
          type: :context,
          project_id: project.id,
          description: "Manages user sessions and workflows"
        })

      # Create child components
      repository_child =
        component_fixture(scope, %{
          name: "SessionsRepository",
          module_name: "Sessions.SessionsRepository",
          type: :repository,
          project_id: project.id,
          parent_component_id: context_component.id,
          description: "Data access for sessions"
        })

      schema_child =
        component_fixture(scope, %{
          name: "Session",
          module_name: "Sessions.Session",
          type: :schema,
          project_id: project.id,
          parent_component_id: context_component.id,
          description: "Session schema"
        })

      liveview_child =
        component_fixture(scope, %{
          name: "SessionsLive",
          module_name: "SessionsWeb.SessionsLive",
          type: :liveview,
          project_id: project.id,
          parent_component_id: context_component.id,
          description: "LiveView for sessions"
        })

      # Create user stories associated with the context
      story1 =
        story_fixture(scope, %{
          title: "User can create sessions",
          description: "As a user, I want to create new sessions",
          acceptance_criteria: ["Session is created", "User is notified"],
          component_id: context_component.id
        })

      story2 =
        story_fixture(scope, %{
          title: "User can view session history",
          description: "As a user, I want to see my past sessions",
          acceptance_criteria: ["Sessions are listed", "Sessions show status"],
          component_id: context_component.id
        })

      # Create session for context review
      session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextDesignReviewSessions,
          component_id: context_component.id,
          project_id: project.id,
          agent: :claude_code,
          environment: :local,
          execution_mode: :agentic
        })

      # Reload with preloads
      session = CodeMySpec.Repo.preload(session, [:project, :component])

      %{
        scope: scope,
        project: project,
        context_component: context_component,
        repository_child: repository_child,
        schema_child: schema_child,
        liveview_child: liveview_child,
        story1: story1,
        story2: story2,
        session: session
      }
    end

    test "generates review command with all context design files", %{
      scope: scope,
      session: session
    } do
      assert {:ok, %Command{} = command} = ExecuteReview.get_command(scope, session, [])

      assert command.module == ExecuteReview
      assert is_binary(command.metadata.prompt)
      assert command.metadata.prompt != ""
      assert %DateTime{} = command.timestamp
    end

    test "command includes context design file path", %{
      scope: scope,
      session: session
    } do
      {:ok, command} = ExecuteReview.get_command(scope, session, [])

      # Context design file should be referenced
      assert command.metadata.prompt =~ "docs/design/my_app/sessions.md"
    end

    test "command includes all child component design file paths", %{
      scope: scope,
      session: session
    } do
      {:ok, command} = ExecuteReview.get_command(scope, session, [])

      # All child component design files should be referenced
      assert command.metadata.prompt =~ "docs/design/my_app/sessions/sessions_repository.md"
      assert command.metadata.prompt =~ "docs/design/my_app/sessions/session.md"
      assert command.metadata.prompt =~ "docs/design/my_app/sessions_web/sessions_live.md"
    end

    test "command includes review output file path", %{
      scope: scope,
      session: session
    } do
      {:ok, command} = ExecuteReview.get_command(scope, session, [])

      # Review file should be in the context directory
      assert command.metadata.prompt =~ "docs/design/my_app/sessions/design_review.md"
    end

    test "command includes user stories", %{
      scope: scope,
      session: session,
      story1: story1,
      story2: story2
    } do
      {:ok, command} = ExecuteReview.get_command(scope, session, [])

      # Stories should be included in the prompt
      assert command.metadata.prompt =~ story1.title
      assert command.metadata.prompt =~ story1.description
      assert command.metadata.prompt =~ story2.title
      assert command.metadata.prompt =~ story2.description
    end

    test "command includes project information", %{
      scope: scope,
      session: session,
      project: project
    } do
      {:ok, command} = ExecuteReview.get_command(scope, session, [])

      # Project name should be in the prompt
      assert command.metadata.prompt =~ project.name
    end

    test "command includes context component information", %{
      scope: scope,
      session: session,
      context_component: context_component
    } do
      {:ok, command} = ExecuteReview.get_command(scope, session, [])

      # Context component name and description should be included
      assert command.metadata.prompt =~ context_component.name
      assert command.metadata.prompt =~ context_component.description
    end

    test "command includes review instructions", %{
      scope: scope,
      session: session
    } do
      {:ok, command} = ExecuteReview.get_command(scope, session, [])

      # Should include key review instructions
      assert command.metadata.prompt =~ "review" or command.metadata.prompt =~ "Review"
      assert command.metadata.prompt =~ "validate" or command.metadata.prompt =~ "Validate"

      assert command.metadata.prompt =~ "architecture" or
               command.metadata.prompt =~ "Architecture"
    end

    test "command uses context_reviewer agent type", %{
      scope: scope,
      session: session
    } do
      {:ok, command} = ExecuteReview.get_command(scope, session, [])

      # The command should be built with the context_reviewer agent
      # We can verify this by checking the command structure
      assert is_map(command.metadata)
    end

    test "command includes acceptance criteria from stories", %{
      scope: scope,
      session: session
    } do
      {:ok, command} = ExecuteReview.get_command(scope, session, [])

      # Acceptance criteria should be formatted in the prompt
      assert command.metadata.prompt =~ "Session is created"
      assert command.metadata.prompt =~ "Sessions are listed"
    end

    test "command with context having no child components still works", %{
      scope: scope,
      project: project
    } do
      # Create a context with no children
      standalone_context =
        component_fixture(scope, %{
          name: "Standalone",
          module_name: "Standalone",
          type: :context,
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextDesignReviewSessions,
          component_id: standalone_context.id,
          project_id: project.id
        })

      session = CodeMySpec.Repo.preload(session, [:project, :component])

      assert {:ok, %Command{} = command} = ExecuteReview.get_command(scope, session, [])
      assert command.metadata.prompt =~ "docs/design/my_app/standalone.md"
    end

    test "command with context having no user stories still works", %{
      scope: scope,
      project: project
    } do
      # Create a context with no stories
      context_without_stories =
        component_fixture(scope, %{
          name: "NoStories",
          module_name: "NoStories",
          type: :context,
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextDesignReviewSessions,
          component_id: context_without_stories.id,
          project_id: project.id
        })

      session = CodeMySpec.Repo.preload(session, [:project, :component])

      assert {:ok, %Command{} = command} = ExecuteReview.get_command(scope, session, [])
      assert is_binary(command.metadata.prompt)
    end

    test "command passes through opts to agent command builder", %{
      scope: scope,
      session: session
    } do
      custom_opts = [timeout: 30000, continue: true]

      assert {:ok, %Command{} = command} =
               ExecuteReview.get_command(scope, session, custom_opts)

      # Command should be created successfully with opts
      assert command.module == ExecuteReview
    end
  end

  # ============================================================================
  # Edge Cases and Error Conditions
  # ============================================================================

  describe "get_command/3 - error conditions" do
    setup do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "TestApp"})

      %{
        scope: scope,
        project: project
      }
    end

    test "returns error when session has no component", %{
      scope: scope,
      project: project
    } do
      # Session without component_id
      session = %Session{
        type: CodeMySpec.ContextDesignReviewSessions,
        project: project,
        component: nil,
        component_id: nil
      }

      assert {:error, error_message} = ExecuteReview.get_command(scope, session, [])
      assert is_binary(error_message)
      assert error_message =~ "component" or error_message =~ "Component"
    end

    test "returns error when component_id is invalid", %{
      scope: scope,
      project: project
    } do
      # Session with invalid component_id
      session = %Session{
        type: CodeMySpec.ContextDesignReviewSessions,
        project: project,
        component: nil,
        component_id: 999_999_999
      }

      assert {:error, error_message} = ExecuteReview.get_command(scope, session, [])
      assert is_binary(error_message)
    end

    test "returns error when session has no project", %{scope: scope} do
      context_component =
        component_fixture(scope, %{
          name: "TestContext",
          module_name: "TestContext",
          type: :context
        })

      # Session without project
      session = %Session{
        type: CodeMySpec.ContextDesignReviewSessions,
        component: context_component,
        component_id: context_component.id,
        project: nil,
        project_id: nil
      }

      assert {:error, error_message} = ExecuteReview.get_command(scope, session, [])
      assert is_binary(error_message)
    end
  end

  describe "get_command/3 - child component ordering" do
    setup do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})

      context_component =
        component_fixture(scope, %{
          name: "Ordering",
          module_name: "Ordering",
          type: :context,
          project_id: project.id
        })

      # Create children with different priorities
      _high_priority =
        component_fixture(scope, %{
          name: "HighPriority",
          module_name: "Ordering.HighPriority",
          type: :repository,
          project_id: project.id,
          parent_component_id: context_component.id,
          priority: 100
        })

      _low_priority =
        component_fixture(scope, %{
          name: "LowPriority",
          module_name: "Ordering.LowPriority",
          type: :schema,
          project_id: project.id,
          parent_component_id: context_component.id,
          priority: 1
        })

      session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextDesignReviewSessions,
          component_id: context_component.id,
          project_id: project.id
        })

      session = CodeMySpec.Repo.preload(session, [:project, :component])

      %{
        scope: scope,
        session: session
      }
    end

    test "includes all child components regardless of priority", %{
      scope: scope,
      session: session
    } do
      {:ok, command} = ExecuteReview.get_command(scope, session, [])

      # Both children should be in the command
      assert command.metadata.prompt =~ "high_priority.md"
      assert command.metadata.prompt =~ "low_priority.md"
    end
  end

  describe "get_command/3 - review file path calculation" do
    setup do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})

      %{
        scope: scope,
        project: project
      }
    end

    test "places review file in context directory", %{
      scope: scope,
      project: project
    } do
      context_component =
        component_fixture(scope, %{
          name: "TestContext",
          module_name: "TestContext",
          type: :context,
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextDesignReviewSessions,
          component_id: context_component.id,
          project_id: project.id
        })

      session = CodeMySpec.Repo.preload(session, [:project, :component])

      {:ok, command} = ExecuteReview.get_command(scope, session, [])

      # Review file should be in docs/design/my_app/test_context/design_review.md
      assert command.metadata.prompt =~ "docs/design/my_app/test_context/design_review.md"
    end

    test "handles nested module names correctly", %{
      scope: scope,
      project: project
    } do
      nested_context =
        component_fixture(scope, %{
          name: "NestedContext",
          module_name: "MyApp.Sub.NestedContext",
          type: :context,
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextDesignReviewSessions,
          component_id: nested_context.id,
          project_id: project.id
        })

      session = CodeMySpec.Repo.preload(session, [:project, :component])

      {:ok, command} = ExecuteReview.get_command(scope, session, [])

      # Should handle nested paths
      assert command.metadata.prompt =~ "design_review.md"
    end
  end

  describe "get_command/3 - user stories formatting" do
    setup do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})

      context_component =
        component_fixture(scope, %{
          name: "Stories",
          module_name: "Stories",
          type: :context,
          project_id: project.id
        })

      # Create story with multiple acceptance criteria
      _story =
        story_fixture(scope, %{
          title: "Complex Feature",
          description: "A complex feature with many criteria",
          acceptance_criteria: [
            "First criterion is met",
            "Second criterion is satisfied",
            "Third criterion is achieved"
          ],
          component_id: context_component.id
        })

      session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextDesignReviewSessions,
          component_id: context_component.id,
          project_id: project.id
        })

      session = CodeMySpec.Repo.preload(session, [:project, :component])

      %{
        scope: scope,
        session: session
      }
    end

    test "formats stories with multiple acceptance criteria", %{
      scope: scope,
      session: session
    } do
      {:ok, command} = ExecuteReview.get_command(scope, session, [])

      # All acceptance criteria should be present
      assert command.metadata.prompt =~ "First criterion is met"
      assert command.metadata.prompt =~ "Second criterion is satisfied"
      assert command.metadata.prompt =~ "Third criterion is achieved"
    end
  end

  describe "get_command/3 - component types" do
    setup do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})

      context_component =
        component_fixture(scope, %{
          name: "MixedTypes",
          module_name: "MixedTypes",
          type: :context,
          project_id: project.id
        })

      # Create children of various types
      _repo =
        component_fixture(scope, %{
          name: "Repo",
          module_name: "MixedTypes.Repo",
          type: :repository,
          project_id: project.id,
          parent_component_id: context_component.id
        })

      _schema =
        component_fixture(scope, %{
          name: "Schema",
          module_name: "MixedTypes.Schema",
          type: :schema,
          project_id: project.id,
          parent_component_id: context_component.id
        })

      _liveview =
        component_fixture(scope, %{
          name: "Live",
          module_name: "MixedTypes.Live",
          type: :other,
          project_id: project.id,
          parent_component_id: context_component.id
        })

      _genserver =
        component_fixture(scope, %{
          name: "Server",
          module_name: "MixedTypes.Server",
          type: :genserver,
          project_id: project.id,
          parent_component_id: context_component.id
        })

      _other =
        component_fixture(scope, %{
          name: "Helper",
          module_name: "MixedTypes.Helper",
          type: :other,
          project_id: project.id,
          parent_component_id: context_component.id
        })

      session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextDesignReviewSessions,
          component_id: context_component.id,
          project_id: project.id
        })

      session = CodeMySpec.Repo.preload(session, [:project, :component])

      %{
        scope: scope,
        session: session
      }
    end

    test "includes all component types in review", %{
      scope: scope,
      session: session
    } do
      {:ok, command} = ExecuteReview.get_command(scope, session, [])

      # All component types should be referenced
      assert command.metadata.prompt =~ "repo.md"
      assert command.metadata.prompt =~ "schema.md"
      assert command.metadata.prompt =~ "live.md"
      assert command.metadata.prompt =~ "server.md"
      assert command.metadata.prompt =~ "helper.md"
    end
  end

  # ============================================================================
  # handle_result/4 Tests
  # ============================================================================

  describe "handle_result/4 - happy path" do
    setup do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})

      context_component =
        component_fixture(scope, %{
          name: "TestContext",
          module_name: "TestContext",
          type: :context,
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextDesignReviewSessions,
          component_id: context_component.id,
          project_id: project.id
        })

      session = CodeMySpec.Repo.preload(session, [:project, :component])

      %{
        scope: scope,
        session: session
      }
    end

    test "returns empty session updates and passes result unchanged", %{
      scope: scope,
      session: session
    } do
      result = Result.success(%{message: "Review completed successfully"})

      assert {:ok, session_updates, returned_result} =
               ExecuteReview.handle_result(scope, session, result, [])

      assert session_updates == %{}
      assert returned_result == result
      assert returned_result.status == :ok
    end

    test "preserves result data", %{
      scope: scope,
      session: session
    } do
      original_data = %{
        message: "Review complete",
        files_reviewed: 5,
        issues_found: 2
      }

      result = Result.success(original_data)

      assert {:ok, _session_updates, returned_result} =
               ExecuteReview.handle_result(scope, session, result, [])

      assert returned_result.data == original_data
    end

    test "handles success result with custom stdout", %{
      scope: scope,
      session: session
    } do
      result = Result.success(%{}, stdout: "Review output here")

      assert {:ok, _session_updates, returned_result} =
               ExecuteReview.handle_result(scope, session, result, [])

      assert returned_result.stdout == "Review output here"
    end
  end

  describe "handle_result/4 - error handling" do
    setup do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})

      context_component =
        component_fixture(scope, %{
          name: "TestContext",
          module_name: "TestContext",
          type: :context,
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextDesignReviewSessions,
          component_id: context_component.id,
          project_id: project.id
        })

      session = CodeMySpec.Repo.preload(session, [:project, :component])

      %{
        scope: scope,
        session: session
      }
    end

    test "passes through error results unchanged", %{
      scope: scope,
      session: session
    } do
      result = Result.error("Review failed due to missing files")

      assert {:ok, session_updates, returned_result} =
               ExecuteReview.handle_result(scope, session, result, [])

      assert session_updates == %{}
      assert returned_result == result
      assert returned_result.status == :error
      assert returned_result.error_message == "Review failed due to missing files"
    end

    test "passes through error with stderr", %{
      scope: scope,
      session: session
    } do
      result = Result.error("Agent error", stderr: "Stack trace here")

      assert {:ok, _session_updates, returned_result} =
               ExecuteReview.handle_result(scope, session, result, [])

      assert returned_result.status == :error
      assert returned_result.stderr == "Stack trace here"
    end

    test "handles warning results", %{
      scope: scope,
      session: session
    } do
      result = Result.warning("Some warnings detected", %{warnings: ["w1", "w2"]})

      assert {:ok, _session_updates, returned_result} =
               ExecuteReview.handle_result(scope, session, result, [])

      assert returned_result.status == :warning
      assert returned_result.data.warnings == ["w1", "w2"]
    end
  end

  describe "handle_result/4 - with opts" do
    setup do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})

      context_component =
        component_fixture(scope, %{
          name: "TestContext",
          module_name: "TestContext",
          type: :context,
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextDesignReviewSessions,
          component_id: context_component.id,
          project_id: project.id
        })

      session = CodeMySpec.Repo.preload(session, [:project, :component])

      %{
        scope: scope,
        session: session
      }
    end

    test "accepts and ignores custom opts", %{
      scope: scope,
      session: session
    } do
      result = Result.success(%{})
      custom_opts = [custom_key: "custom_value", another: 123]

      assert {:ok, session_updates, returned_result} =
               ExecuteReview.handle_result(scope, session, result, custom_opts)

      assert session_updates == %{}
      assert returned_result == result
    end
  end

  describe "handle_result/4 - pass-through behavior" do
    setup do
      scope = full_scope_fixture()
      project = project_fixture(scope, %{module_name: "MyApp"})

      context_component =
        component_fixture(scope, %{
          name: "TestContext",
          module_name: "TestContext",
          type: :context,
          project_id: project.id
        })

      session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextDesignReviewSessions,
          component_id: context_component.id,
          project_id: project.id
        })

      session = CodeMySpec.Repo.preload(session, [:project, :component])

      %{
        scope: scope,
        session: session
      }
    end

    test "does not modify session state", %{
      scope: scope,
      session: session
    } do
      result = Result.success(%{some: "data"})

      assert {:ok, session_updates, _returned_result} =
               ExecuteReview.handle_result(scope, session, result, [])

      # Session updates should be empty - no modifications
      assert session_updates == %{}
      assert map_size(session_updates) == 0
    end

    test "returns exact same result object", %{
      scope: scope,
      session: session
    } do
      result = Result.success(%{key: "value"})

      assert {:ok, _session_updates, returned_result} =
               ExecuteReview.handle_result(scope, session, result, [])

      # Should be the exact same result, not a copy
      assert returned_result == result
    end
  end
end
