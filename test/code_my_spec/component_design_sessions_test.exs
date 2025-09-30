defmodule CodeMySpec.ComponentDesignSessionsTest do
  alias CodeMySpec.Sessions.Interaction
  use CodeMySpec.DataCase
  import Mox
  import CodeMySpec.Support.CLIRecorder
  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures}
  alias CodeMySpec.{Sessions, Components}
  alias CodeMySpec.ComponentDesignSessions

  alias CodeMySpec.ComponentDesignSessions.Steps.{
    Finalize,
    GenerateComponentDesign,
    Initialize,
    ReadContextDesign,
    ReviseDesign,
    ValidateDesign
  }

  @test_repo_url "https://github.com/johns10/test_phoenix_project.git"

  describe "component design session workflow" do
    setup do
      # Configure application to use mock for local environment
      Application.put_env(:code_my_spec, :local_environment, CodeMySpec.MockEnvironment)

      # Use stub environment that automatically records
      stub_with(CodeMySpec.MockEnvironment, CodeMySpec.Support.RecordingEnvironment)

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
          name: "BlogRepository",
          type: :repository,
          module_name: "TestPhoenixProject.Blog.BlogRepository",
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
      project_dir = "test_phoenix_project"

      # Setup test project (clone only if doesn't exist)
      setup_test_project(project_dir)
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
        {_, _, session} = execute_step(scope, session.id, ReadContextDesign)
        assert String.starts_with?(session.state["context_design"], "# Blog Context")

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [_, %Interaction{}]}}

        {_, _, session} =
          execute_step(
            scope,
            session.id,
            GenerateComponentDesign,
            mock_output: "Generated component design for BlogRepository"
          )

        # Create the design file that would have been created by Claude
        design_file =
          Path.join([
            "test_phoenix_project",
            "docs",
            "design",
            "test_phoenix_project",
            "blog",
            "blog_repository.md"
          ])

        File.mkdir_p!(Path.dirname(design_file))
        File.write!(design_file, invalid_blog_repository_content())

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [_, _, %Interaction{}]}}

        # Step 4: Validate Design
        {_, _, session} =
          execute_step(scope, session.id, ValidateDesign,
            mock_output: invalid_blog_repository_content()
          )

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [_, _, _, %Interaction{result: %{status: :error}}]
                         }}

        # Step 5: Revise Design
        {_, _, session} =
          execute_step(scope, session.id, ReviseDesign,
            mock_output: "Revised component design for BlogRepository"
          )

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [_, _, _, _, %Interaction{}]}}

        # Step 6: Revalidate Design
        {_, _, session} =
          execute_step(scope, session.id, ValidateDesign, mock_output: blog_repository_content())

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [_, _, _, _, _, %Interaction{result: %{status: :ok}}]
                         }}

        # Step 6: Finalize (assuming validation passes)
        {_finalize_interaction, _finalize_result, session} =
          execute_step(scope, session.id, Finalize, mock_output: "Finalized design successfully")

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [_, _, _, _, %Interaction{}]}}

        # Step 6: Session should be complete
        assert {:error, :session_complete} = Sessions.next_command(scope, session.id)

        # Verify final state
        assert session.state["component_design"] != nil
        assert is_binary(session.state["component_design"])
      end
    end
  end

  # Helper function to execute a session step with common pattern
  defp execute_step(scope, session_id, expected_module, opts \\ []) do
    cd_opts = Keyword.get(opts, :cd_opts, cd: "test_phoenix_project")
    mock_output = Keyword.get(opts, :mock_output)

    {:ok, interaction} = Sessions.next_command(scope, session_id)
    assert interaction.command.module == expected_module

    result =
      if mock_output do
        %{status: :ok, stdout: mock_output, stderr: "", exit_code: 0}
      else
        {:ok, output} =
          CodeMySpec.Environments.cmd(:local, "sh", ["-c", interaction.command.command], cd_opts)

        %{status: :ok, stdout: output, stderr: "", exit_code: 0}
      end

    {:ok, updated_session} = Sessions.handle_result(scope, session_id, interaction.id, result)
    {interaction, result, updated_session}
  end

  # Helper function to setup test project (only clone if needed)
  defp setup_test_project(project_dir) do
    if File.exists?(project_dir) do
      # Update existing repository
      System.cmd("git", ["fetch", "origin"], cd: project_dir)
      System.cmd("git", ["reset", "--hard", "origin/main"], cd: project_dir)
    else
      # Clone fresh copy
      System.cmd("git", [
        "clone",
        "--recurse-submodules",
        @test_repo_url,
        project_dir
      ])
    end

    # Ensure dependencies are up to date
    unless File.exists?(Path.join(project_dir, "deps")) do
      System.cmd("mix", ["deps.get"], cd: project_dir)
    end
  end

  defp invalid_blog_repository_content() do
    """
    # BlogRepository Component Design

    ## Purpose
    Repository for managing blog persistence in the blog context.

    ## Interface
    - get_blog/1
    - create_blog/1
    - update_blog/2
    - delete_blog/1

    ## Implementation Notes
    Generated component design for BlogRepository
    """
  end

  defp blog_repository_content() do
    """
    # BlogRepository Component Design

    ## Purpose
    Repository for managing blog persistence in the blog context.

    ## Public API
    - get_blog/1
    - create_blog/1
    - update_blog/2
    - delete_blog/1

    ## Execution Flow
    1. Receive scoped request
    2. Execute database operation with user filtering
    3. Return result or error
    """
  end
end
