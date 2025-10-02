defmodule CodeMySpec.ComponentCodingSessionsTest do
  alias CodeMySpec.Sessions.Interaction
  use CodeMySpec.DataCase
  import Mox
  import CodeMySpec.Support.CLIRecorder
  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures}
  alias CodeMySpec.{Sessions, Components}
  alias CodeMySpec.ComponentCodingSessions

  alias CodeMySpec.ComponentCodingSessions.Steps.{
    Finalize,
    FixTestFailures,
    GenerateImplementation,
    GenerateTests,
    Initialize,
    ReadComponentDesign,
    RunTests
  }

  @test_repo_url "https://github.com/johns10/test_phoenix_project.git"

  describe "component coding session workflow" do
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

      # Create test component to implement (BlogRepository)
      {:ok, blog_repository} =
        Components.create_component(scope, %{
          name: "BlogRepository",
          type: :repository,
          module_name: "TestPhoenixProject.Blog.BlogRepository",
          description: "Repository for blog persistence",
          parent_component_id: blog_context.id
        })

      %{scope: scope, blog_context: blog_context, blog_repository: blog_repository}
    end

    @tag timeout: 300_000
    # @tag :integration
    test "executes complete component coding workflow", %{
      scope: scope,
      blog_repository: blog_repository
    } do
      project_dir = "test_phoenix_project"

      # Setup test project (clone only if doesn't exist)
      setup_test_project(project_dir)
      CodeMySpec.Sessions.subscribe_sessions(scope)

      # Use CLI recorder for the session
      use_cassette "component_coding_workflow" do
        # Create component coding session
        {:ok, session} =
          Sessions.create_session(scope, %{
            type: ComponentCodingSessions,
            agent: :claude_code,
            environment: :local,
            component_id: blog_repository.id
          })

        # Step 1: Initialize
        {_, _, session} = execute_step(scope, session.id, Initialize)
        assert_received {:updated, %CodeMySpec.Sessions.Session{interactions: [%Interaction{}]}}

        # Step 2: Read Component Design
        {_, _, session} = execute_step(scope, session.id, ReadComponentDesign)
        assert String.starts_with?(session.state["component_design"], "# BlogRepository")

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [_, %Interaction{}]}}

        # Step 3: Generate Tests
        {_, _, session} =
          execute_step(
            scope,
            session.id,
            GenerateTests,
            mock_output: "Generated tests for BlogRepository"
          )

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [_, _, %Interaction{}]}}

        # Step 4: Generate Implementation
        {_, _, session} =
          execute_step(
            scope,
            session.id,
            GenerateImplementation,
            mock_output: "Generated implementation for BlogRepository"
          )

        # Write the actual files that would have been generated
        write_implementation_files(project_dir)

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [_, _, _, %Interaction{}]}}

        # Step 5: Run Tests (with failures) - real test execution
        {_, result, session} = execute_step(scope, session.id, RunTests, seed: 1)

        # Verify we got a failure
        assert result.status == :error
        assert result.data.stats.tests == 1
        assert result.data.stats.failures == 1

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [_, _, _, _, %Interaction{result: %{status: :error}}]
                         }}

        # Step 6: Fix Test Failures
        {_, _, session} =
          execute_step(scope, session.id, FixTestFailures, mock_output: "Fixed test failures")

        # Actually fix the test file
        fix_test_file(project_dir)

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [_, _, _, _, _, %Interaction{}]
                         }}

        # Step 7: Run Tests Again (passing) - real test execution
        {_, result, session} = execute_step(scope, session.id, RunTests, seed: 2)

        # Verify tests now pass
        assert result.status == :ok
        assert result.data.stats.tests == 1
        assert result.data.stats.failures == 0

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [_, _, _, _, _, _, %Interaction{result: %{status: :ok}}]
                         }}

        # Step 8: Finalize
        {_finalize_interaction, _finalize_result, session} =
          execute_step(scope, session.id, Finalize)

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [_, _, _, _, _, _, _, %Interaction{}]
                         }}

        # Session should be complete
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

    {:ok, interaction} = Sessions.next_command(scope, session_id, opts)
    assert interaction.command.module == expected_module

    result =
      if mock_output do
        %{status: :ok, stdout: mock_output, stderr: "", exit_code: 0}
      else
        {output, _code} =
          CodeMySpec.Environments.cmd(:local, "sh", ["-c", interaction.command.command], cd_opts)

        %{status: :ok, stdout: output, stderr: "", exit_code: 0}
      end

    {:ok, updated_session} =
      Sessions.handle_result(scope, session_id, interaction.id, result)

    final_result =
      updated_session
      |> Map.get(:interactions)
      |> List.last()
      |> Map.get(:result)

    {interaction, final_result, updated_session}
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

  # Write implementation and test files to the test project
  defp write_implementation_files(project_dir) do
    # Read fixtures
    impl_content = File.read!("test/fixtures/component_coding/blog_repository.ex")
    test_content = File.read!("test/fixtures/component_coding/blog_repository_test.ex")

    # Write implementation file
    impl_path =
      Path.join([project_dir, "lib", "test_phoenix_project", "blog", "blog_repository.ex"])

    File.mkdir_p!(Path.dirname(impl_path))
    File.write!(impl_path, impl_content)

    # Write test file
    test_path =
      Path.join([project_dir, "test", "test_phoenix_project", "blog", "blog_repository_test.exs"])

    File.mkdir_p!(Path.dirname(test_path))
    File.write!(test_path, test_content)
  end

  # Fix the test file by replacing with the passing version
  defp fix_test_file(project_dir) do
    fixed_content = File.read!("test/fixtures/component_coding/blog_repository_test_fixed.ex")

    test_path =
      Path.join([project_dir, "test", "test_phoenix_project", "blog", "blog_repository_test.exs"])

    File.write!(test_path, fixed_content)
  end
end
