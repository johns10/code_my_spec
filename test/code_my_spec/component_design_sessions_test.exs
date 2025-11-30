defmodule CodeMySpec.ComponentDesignSessionsTest do
  alias CodeMySpec.Sessions.Interaction
  use CodeMySpec.DataCase
  import CodeMySpec.Support.CLIRecorder
  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures}
  alias CodeMySpec.{Sessions, Components}
  alias CodeMySpec.ComponentDesignSessions

  alias CodeMySpec.ComponentDesignSessions.Steps.{
    Finalize,
    GenerateComponentDesign,
    Initialize,
    ReviseDesign,
    ValidateDesign
  }

  @test_repo_url "https://github.com/johns10/test_phoenix_project.git"

  describe "component design session workflow" do
    setup do
      user = user_fixture()
      account = account_fixture()
      member_fixture(user, account)

      project =
        user_scope_fixture(user, account)
        |> project_fixture(%{account_id: account.id, module_name: "TestPhoenixProject"})

      scope = user_scope_fixture(user, account, project)

      # Create test parent component (Blog context)
      {:ok, blog_context} =
        Components.create_component(scope, %{
          name: "Blog",
          type: :context,
          module_name: "TestPhoenixProject.Blog",
          description: "Blog context for managing posts"
        })

      # Create test component to design (PostService)
      {:ok, post_service} =
        Components.create_component(scope, %{
          name: "PostRepository",
          type: :repository,
          module_name: "TestPhoenixProject.Blog.PostRepository",
          description: "Repository for blog persistence",
          parent_component_id: blog_context.id
        })

      %{scope: scope, blog_context: blog_context, post_service: post_service}
    end

    @tag timeout: 300_000
    # @tag :integration
    test "executes complete component design workflow", %{
      scope: scope,
      post_service: post_service
    } do
      project_dir =
        "../code_my_spec_test_repos/component_design_session_#{System.unique_integer([:positive])}"

      # Setup test project using TestAdapter
      {:ok, ^project_dir} =
        CodeMySpec.Support.TestAdapter.clone(scope, @test_repo_url, project_dir)

      CodeMySpec.Sessions.subscribe_sessions(scope)

      # Use CLI recorder for the session
      use_cassette "component_design_workflow" do
        # Create component design session
        {:ok, session} =
          Sessions.create_session(scope, %{
            type: ComponentDesignSessions,
            agent: :claude_code,
            environment: :local,
            component_id: post_service.id
          })

        {_, _, session} = execute_step(scope, session.id, Initialize)
        assert_received {:updated, %CodeMySpec.Sessions.Session{interactions: [%Interaction{}]}}

        {_, _, session} =
          execute_step(
            scope,
            session.id,
            GenerateComponentDesign,
            mock_output: "Generated component design for PostRepository"
          )

        # Create the design file that would have been created by Claude
        design_file =
          Path.join([
            project_dir,
            "docs",
            "design",
            "test_phoenix_project",
            "blog",
            "post_repository.md"
          ])

        File.mkdir_p!(Path.dirname(design_file))
        File.write!(design_file, invalid_post_repository_content())

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [%Interaction{}, _]}}

        # Step 4: Validate Design
        {_, _, session} =
          execute_step(scope, session.id, ValidateDesign,
            mock_output: invalid_post_repository_content()
          )

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{result: %{status: :error}}, _, _]
                         }}

        # Step 5: Revise Design
        {_, _, session} =
          execute_step(scope, session.id, ReviseDesign,
            mock_output: "Revised component design for PostRepository"
          )

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [%Interaction{}, _, _, _]}}

        # Step 6: Revalidate Design
        {_, _, session} =
          execute_step(scope, session.id, ValidateDesign, mock_output: post_repository_content())

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{result: %{status: :ok}}, _, _, _, _]
                         }}

        # Step 6: Finalize (assuming validation passes)
        {_finalize_interaction, _finalize_result, session} =
          execute_step(scope, session.id, Finalize, mock_output: "Finalized design successfully")

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [%Interaction{}, _, _, _, _]}}

        # Step 6: Session should be complete
        assert {:error, :complete} = Sessions.next_command(scope, session.id)

        # Verify final state
        assert session.state["component_design"] != nil
        assert is_binary(session.state["component_design"])
      end
    end
  end

  # Helper function to execute a session step with common pattern
  defp execute_step(scope, session_id, expected_module, opts \\ []) do
    cd_opts = Keyword.get(opts, :cd_opts, [])
    mock_output = Keyword.get(opts, :mock_output)

    {:ok, session} = Sessions.next_command(scope, session_id, opts)
    [interaction | _] = session.interactions
    assert interaction.command.module == expected_module

    result =
      if mock_output do
        %{status: :ok, stdout: mock_output, stderr: "", exit_code: 0}
      else
        {output, code} =
          CodeMySpec.Environments.cmd(:local, "sh", ["-c", interaction.command.command], cd_opts)

        %{status: :ok, stdout: output, stderr: "", exit_code: code}
      end

    {:ok, updated_session} =
      Sessions.handle_result(scope, session_id, interaction.id, result)

    [final_interaction | _] = updated_session.interactions
    final_result = Map.get(final_interaction, :result)

    {final_interaction, final_result, updated_session}
  end

  defp invalid_post_repository_content() do
    """
    # PostRepository Component Design

    ## Purpose
    Repository for managing blog persistence in the blog context.

    ## Interface
    - get_post/1
    - create_post/1
    - update_post/2
    - delete_post/1

    ## Implementation Notes
    Generated component design for PostRepository
    """
  end

  defp post_repository_content() do
    """
    # PostRepository Component Design

    ## Purpose
    Repository for managing blog persistence in the blog context.

    ## Public API
    - get_post/1
    - create_post/1
    - update_post/2
    - delete_post/1

    ## Execution Flow
    1. Receive scoped request
    2. Execute database operation with user filtering
    3. Return result or error

    ## Test Assertions
    1. It does the thing
    """
  end
end
