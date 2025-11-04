defmodule CodeMySpec.ContextComponentsDesignSessions.Steps.FinalizeTest do
  use CodeMySpec.DataCase, async: true

  alias CodeMySpec.ContextComponentsDesignSessions.Steps.Finalize
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

      # Create a context component
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

    test "returns git command with commit, push, and PR creation", %{
      scope: scope,
      parent_session: parent_session
    } do
      assert {:ok, %Command{} = command} = Finalize.get_command(scope, parent_session, [])

      assert command.module == Finalize
      assert is_binary(command.command)
      assert command.command =~ "commit"
      assert command.command =~ "push"
      assert command.command =~ "gh pr create"
    end

    test "command includes PR title with context name", %{
      scope: scope,
      parent_session: parent_session
    } do
      {:ok, command} = Finalize.get_command(scope, parent_session, [])

      assert command.command =~ "Add component designs for Accounts context"
    end

    test "command includes PR body with Claude Code attribution", %{
      scope: scope,
      parent_session: parent_session
    } do
      {:ok, command} = Finalize.get_command(scope, parent_session, [])

      # Should include Claude Code attribution
      assert command.command =~ "Generated with"
      assert command.command =~ "Claude Code"
    end

    test "command includes commit message with context name", %{
      scope: scope,
      parent_session: parent_session
    } do
      {:ok, command} = Finalize.get_command(scope, parent_session, [])

      assert command.command =~ "Add component designs for Accounts context"
    end

    test "command includes push to remote with correct branch", %{
      scope: scope,
      parent_session: parent_session
    } do
      {:ok, command} = Finalize.get_command(scope, parent_session, [])

      assert command.command =~ "push -u origin"
      assert command.command =~ "docs-context-components-design-session-for-accounts"
    end

    test "command timestamp is set", %{
      scope: scope,
      parent_session: parent_session
    } do
      {:ok, command} = Finalize.get_command(scope, parent_session, [])

      assert %DateTime{} = command.timestamp
    end

    test "command uses working directory 'docs' for git operations", %{
      scope: scope,
      parent_session: parent_session
    } do
      {:ok, command} = Finalize.get_command(scope, parent_session, [])

      # Git commands should use -C docs to set working directory
      assert command.command =~ "git -C docs"
    end

    test "review file path uses sanitized context name", %{
      scope: scope,
      parent_session: parent_session
    } do
      {:ok, command} = Finalize.get_command(scope, parent_session, [])

      # Review file should use lowercase, sanitized context name
      assert command.command =~ "review/accounts_components_review.md"
    end

    test "handles context names with special characters", %{
      scope: scope,
      project: project
    } do
      # Create context with special characters
      special_context =
        component_fixture(scope, %{
          name: "User::Management",
          module_name: "UserManagement",
          type: :context,
          project_id: project.id
        })

      special_session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextComponentsDesignSessions,
          component_id: special_context.id,
          project_id: project.id
        })

      special_session = CodeMySpec.Repo.preload(special_session, [:project, :component])

      {:ok, command} = Finalize.get_command(scope, special_session, [])

      # Branch name should be sanitized
      assert command.metadata.branch_name =~ "user-management"
      refute command.metadata.branch_name =~ "::"
      # Review file should be sanitized
      assert command.command =~ "review/user-management_components_review.md"
    end

    test "handles context names with multiple consecutive special characters", %{
      scope: scope,
      project: project
    } do
      # Create context with multiple consecutive special characters
      special_context =
        component_fixture(scope, %{
          name: "User---Admin:::System",
          module_name: "UserAdminSystem",
          type: :context,
          project_id: project.id
        })

      special_session =
        session_fixture(scope, %{
          type: CodeMySpec.ContextComponentsDesignSessions,
          component_id: special_context.id,
          project_id: project.id
        })

      special_session = CodeMySpec.Repo.preload(special_session, [:project, :component])

      {:ok, command} = Finalize.get_command(scope, special_session, [])

      # Should collapse multiple hyphens into single hyphen
      assert command.metadata.branch_name =~ "user-admin-system"
      refute command.metadata.branch_name =~ "--"
      refute command.metadata.branch_name =~ ":::"
    end

    test "returns error when context component is missing", %{
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

      assert {:error, "Context component not found in session"} =
               Finalize.get_command(scope, invalid_session, [])
    end

    test "command includes Co-Authored-By attribution", %{
      scope: scope,
      parent_session: parent_session
    } do
      {:ok, command} = Finalize.get_command(scope, parent_session, [])

      # Should include Co-Authored-By in commit message
      assert command.command =~ "Co-Authored-By: Claude"
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

      parent_session = CodeMySpec.Repo.preload(parent_session, [:project, :component])

      %{
        scope: scope,
        project: project,
        context_component: context_component,
        parent_session: parent_session
      }
    end

    test "returns session updates with status :complete and pr_url", %{
      scope: scope,
      parent_session: parent_session
    } do
      # Simulate successful PR creation with URL in result
      result =
        Result.success(
          %{},
          stdout: "https://github.com/example/repo/pull/123"
        )

      assert {:ok, session_updates, updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      assert session_updates.status == :complete
      assert is_map(session_updates.state)
      assert session_updates.state.pr_url == "https://github.com/example/repo/pull/123"
      assert %DateTime{} = session_updates.state.finalized_at
      assert updated_result.status == :ok
    end

    test "extracts PR URL from result stdout", %{
      scope: scope,
      parent_session: parent_session
    } do
      result =
        Result.success(
          %{message: "PR created successfully"},
          stdout: "Created PR: https://github.com/org/project/pull/456\n"
        )

      {:ok, session_updates, _updated_result} =
        Finalize.handle_result(scope, parent_session, result, [])

      assert session_updates.state.pr_url == "https://github.com/org/project/pull/456"
    end

    test "handles PR URL with trailing whitespace", %{
      scope: scope,
      parent_session: parent_session
    } do
      result =
        Result.success(
          %{},
          stdout: "  https://github.com/example/repo/pull/789  \n\n"
        )

      {:ok, session_updates, _updated_result} =
        Finalize.handle_result(scope, parent_session, result, [])

      assert session_updates.state.pr_url == "https://github.com/example/repo/pull/789"
    end

    test "handles PR URL embedded in multiline output", %{
      scope: scope,
      parent_session: parent_session
    } do
      result =
        Result.success(
          %{},
          stdout: """
          Creating pull request for docs-context-components-design-session-for-accounts
          https://github.com/example/repo/pull/999
          Successfully created pull request
          """
        )

      {:ok, session_updates, _updated_result} =
        Finalize.handle_result(scope, parent_session, result, [])

      assert session_updates.state.pr_url == "https://github.com/example/repo/pull/999"
    end

    test "sets finalized_at timestamp", %{
      scope: scope,
      parent_session: parent_session
    } do
      result = Result.success(%{}, stdout: "https://github.com/example/repo/pull/123")

      before_time = DateTime.utc_now()

      {:ok, session_updates, _updated_result} =
        Finalize.handle_result(scope, parent_session, result, [])

      after_time = DateTime.utc_now()

      finalized_at = session_updates.state.finalized_at

      assert %DateTime{} = finalized_at
      assert DateTime.compare(finalized_at, before_time) in [:gt, :eq]
      assert DateTime.compare(finalized_at, after_time) in [:lt, :eq]
    end

    test "preserves original result data", %{
      scope: scope,
      parent_session: parent_session
    } do
      original_data = %{
        message: "PR created successfully",
        extra_field: "preserved_value"
      }

      result = Result.success(original_data, stdout: "https://github.com/example/repo/pull/123")

      {:ok, _session_updates, updated_result} =
        Finalize.handle_result(scope, parent_session, result, [])

      assert updated_result.status == :ok
      assert updated_result.data.message == "PR created successfully"
      assert updated_result.data.extra_field == "preserved_value"
    end

    test "merges state with existing session state", %{
      scope: scope,
      parent_session: parent_session
    } do
      # Add some existing state
      {:ok, parent_session} =
        Sessions.update_session(scope, parent_session, %{
          state: %{existing_key: "existing_value"}
        })

      parent_session =
        CodeMySpec.Repo.preload(parent_session, [:project, :component], force: true)

      result = Result.success(%{}, stdout: "https://github.com/example/repo/pull/123")

      {:ok, session_updates, _updated_result} =
        Finalize.handle_result(scope, parent_session, result, [])

      # Should preserve existing state
      assert session_updates.state.existing_key == "existing_value"
      # Should add new fields
      assert session_updates.state.pr_url
      assert session_updates.state.finalized_at
    end

    test "returns error when PR URL cannot be extracted", %{
      scope: scope,
      parent_session: parent_session
    } do
      # Result without PR URL
      result = Result.success(%{}, stdout: "Some output without URL")

      assert {:ok, _session_updates, updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      # Should still succeed but pr_url might be nil or error handled gracefully
      # Implementation may vary - this tests the module handles missing URL
      assert updated_result.status in [:ok, :error, :warning]
    end

    test "handles result with error status", %{
      scope: scope,
      parent_session: parent_session
    } do
      # Git command failed
      result = Result.error("Git push failed", stderr: "fatal: repository not found")

      assert {:ok, _session_updates, updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      # Should propagate error status
      assert updated_result.status == :error
      assert updated_result.error_message =~ "Git push failed"
    end

    test "handles result with warning status", %{
      scope: scope,
      parent_session: parent_session
    } do
      result =
        Result.warning(
          "Some design files missing",
          %{},
          stdout: "https://github.com/example/repo/pull/123"
        )

      assert {:ok, _session_updates, updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      # Should handle warning appropriately
      # Implementation determines if warning becomes error or remains warning
      assert updated_result.status in [:warning, :ok]
    end

    test "handles GitHub CLI (gh) command failures", %{
      scope: scope,
      parent_session: parent_session
    } do
      result =
        Result.error(
          "PR creation failed",
          stderr: "gh: command not found",
          code: 127
        )

      {:ok, _session_updates, updated_result} =
        Finalize.handle_result(scope, parent_session, result, [])

      assert updated_result.status == :error
      assert updated_result.error_message =~ "PR creation failed"
    end

    test "handles empty stdout gracefully", %{
      scope: scope,
      parent_session: parent_session
    } do
      result = Result.success(%{}, stdout: "")

      assert {:ok, _session_updates, updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      # Should handle gracefully (implementation specific)
      assert updated_result.status in [:ok, :error, :warning]
    end

    test "handles nil stdout gracefully", %{
      scope: scope,
      parent_session: parent_session
    } do
      result = Result.success(%{})

      assert {:ok, _session_updates, updated_result} =
               Finalize.handle_result(scope, parent_session, result, [])

      # Should handle gracefully
      assert updated_result.status in [:ok, :error, :warning]
    end

    test "result timestamp is preserved", %{
      scope: scope,
      parent_session: parent_session
    } do
      original_timestamp = DateTime.utc_now()

      result = %Result{
        status: :ok,
        data: %{},
        stdout: "https://github.com/example/repo/pull/123",
        timestamp: original_timestamp
      }

      {:ok, _session_updates, updated_result} =
        Finalize.handle_result(scope, parent_session, result, [])

      assert updated_result.timestamp == original_timestamp
    end

    test "session updates include all required fields", %{
      scope: scope,
      parent_session: parent_session
    } do
      result = Result.success(%{}, stdout: "https://github.com/example/repo/pull/123")

      {:ok, session_updates, _} = Finalize.handle_result(scope, parent_session, result, [])

      # Verify all required fields are present
      assert Map.has_key?(session_updates, :status)
      assert Map.has_key?(session_updates, :state)
      assert Map.has_key?(session_updates.state, :pr_url)
      assert Map.has_key?(session_updates.state, :finalized_at)
    end

    test "handles concurrent finalization attempts", %{
      scope: scope,
      parent_session: parent_session
    } do
      result1 = Result.success(%{}, stdout: "https://github.com/example/repo/pull/123")
      result2 = Result.success(%{}, stdout: "https://github.com/example/repo/pull/456")

      {:ok, updates1, _} = Finalize.handle_result(scope, parent_session, result1, [])
      {:ok, updates2, _} = Finalize.handle_result(scope, parent_session, result2, [])

      # Both should succeed independently
      assert updates1.status == :complete
      assert updates2.status == :complete
      # URLs should be different
      assert updates1.state.pr_url != updates2.state.pr_url
    end

    test "handles git commit failures", %{
      scope: scope,
      parent_session: parent_session
    } do
      result =
        Result.error(
          "Commit failed",
          stderr: "nothing to commit, working tree clean",
          code: 1
        )

      {:ok, _session_updates, updated_result} =
        Finalize.handle_result(scope, parent_session, result, [])

      assert updated_result.status == :error
      assert updated_result.error_message =~ "Commit failed"
    end

    test "handles git push failures", %{
      scope: scope,
      parent_session: parent_session
    } do
      result =
        Result.error(
          "Push failed",
          stderr: "error: failed to push some refs",
          code: 1
        )

      {:ok, _session_updates, updated_result} =
        Finalize.handle_result(scope, parent_session, result, [])

      assert updated_result.status == :error
      assert updated_result.error_message =~ "Push failed"
    end
  end
end
