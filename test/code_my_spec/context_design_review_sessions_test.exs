defmodule CodeMySpec.ContextDesignReviewSessionsTest do
  alias CodeMySpec.Sessions.Interaction
  use CodeMySpec.DataCase
  import CodeMySpec.Support.CLIRecorder
  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures}
  alias CodeMySpec.{Sessions, Components}
  alias CodeMySpec.ContextDesignReviewSessions

  alias CodeMySpec.ContextDesignReviewSessions.Steps.{
    ExecuteReview,
    Finalize
  }

  describe "context design review session workflow" do
    setup do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account)

      project =
        user_scope_fixture(user, account)
        |> project_fixture(%{
          account_id: account.id,
          module_name: "TestPhoenixProject",
          directory_path: "test_phoenix_project"
        })

      scope = user_scope_fixture(user, account, project)

      # Create test context component
      {:ok, context_component} =
        Components.create_component(scope, %{
          name: "Blog",
          type: "context",
          module_name: "TestPhoenixProject.Blog",
          description: "Blog context for managing posts"
        })

      # Create a couple child components to make the review more realistic
      {:ok, _post_schema} =
        Components.create_component(scope, %{
          name: "Post",
          type: "schema",
          module_name: "TestPhoenixProject.Blog.Post",
          description: "Blog post schema",
          parent_component_id: context_component.id
        })

      {:ok, _post_repository} =
        Components.create_component(scope, %{
          name: "PostRepository",
          type: "repository",
          module_name: "TestPhoenixProject.Blog.PostRepository",
          description: "Repository for blog persistence",
          parent_component_id: context_component.id
        })

      %{scope: scope, context_component: context_component, project: project}
    end

    @tag timeout: 300_000
    # @tag :integration
    test "executes complete context design review workflow", %{
      scope: scope,
      context_component: context_component
    } do
      CodeMySpec.Sessions.subscribe_sessions(scope)

      # Use CLI recorder for the session
      use_cassette "context_design_review_workflow" do
        # Create context design review session
        {:ok, session} =
          Sessions.create_session(scope, %{
            type: ContextDesignReviewSessions,
            agent: :claude_code,
            environment: :local,
            component_id: context_component.id
          })

        # Step 1: ExecuteReview
        {_, _, session} =
          execute_step(
            scope,
            session.id,
            ExecuteReview,
            mock_output: "Reviewed context and child component designs. All looks good."
          )

        assert_received {:updated, %CodeMySpec.Sessions.Session{interactions: [%Interaction{}]}}

        # Step 2: Finalize
        {_, result, session} = execute_step(scope, session.id, Finalize, mock_output: "")

        # Verify finalize succeeded
        assert result.status == :ok

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{}, _]
                         }}

        # Session should be complete
        assert {:error, :complete} = Sessions.next_command(scope, session.id)

        # Verify session status is complete
        final_session = Sessions.get_session!(scope, session.id)
        assert final_session.status == :complete
      end
    end
  end

  # Helper function to execute a session step with common pattern
  defp execute_step(scope, session_id, expected_module, opts) do
    mock_output = Keyword.get(opts, :mock_output)

    {:ok, session} = Sessions.next_command(scope, session_id, opts)
    [interaction | _] = session.interactions
    assert interaction.command.module == expected_module

    result = %{status: :ok, stdout: mock_output || "", stderr: "", exit_code: 0}

    {:ok, updated_session} =
      Sessions.handle_result(scope, session_id, interaction.id, result)

    [final_interaction | _] = updated_session.interactions
    final_result = Map.get(final_interaction, :result)

    {final_interaction, final_result, updated_session}
  end
end
