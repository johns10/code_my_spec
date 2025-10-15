defmodule CodeMySpec.ComponentTestSessionsTest do
  alias CodeMySpec.Sessions.Interaction
  use CodeMySpec.DataCase
  import CodeMySpec.Support.CLIRecorder
  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures}
  alias CodeMySpec.{Sessions, Components}
  alias CodeMySpec.ComponentTestSessions

  alias CodeMySpec.ComponentTestSessions.Steps.{
    Finalize,
    FixCompilationErrors,
    GenerateTestsAndFixtures,
    Initialize,
    RunTests
  }

  @test_repo_url "https://github.com/johns10/test_phoenix_project.git"

  describe "component test session workflow with undefined module error" do
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

      # Create test component to test (PostCache)
      {:ok, post_cache} =
        Components.create_component(scope, %{
          name: "PostCache",
          type: :genserver,
          module_name: "TestPhoenixProject.Blog.PostCache",
          description: "GenServer for caching posts",
          parent_component_id: blog_context.id
        })

      %{scope: scope, blog_context: blog_context, post_cache: post_cache}
    end

    @tag timeout: 300_000
    # @tag :integration
    test "executes complete component test workflow with undefined module fix", %{
      scope: scope,
      post_cache: post_cache
    } do
      project_dir = "test_repos/component_test_session_#{System.unique_integer([:positive])}"

      # Setup test project using TestAdapter
      {:ok, ^project_dir} =
        CodeMySpec.Support.TestAdapter.clone(scope, @test_repo_url, project_dir)

      CodeMySpec.Sessions.subscribe_sessions(scope)

      # Use CLI recorder for the session
      use_cassette "component_test_workflow_compilation_error" do
        # Create component test session
        {:ok, session} =
          Sessions.create_session(scope, %{
            type: ComponentTestSessions,
            agent: :claude_code,
            environment: :local,
            component_id: post_cache.id
          })

        # Step 1: Initialize
        {_, _, session} = execute_step(scope, session.id, Initialize)
        assert_received {:updated, %CodeMySpec.Sessions.Session{interactions: [%Interaction{}]}}

        # Step 2: Generate Tests and Fixtures
        {_, _, session_before_run_tests} =
          execute_step(
            scope,
            session.id,
            GenerateTestsAndFixtures,
            mock_output: "Generated tests and fixtures for PostCache"
          )

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [_, %Interaction{}]}}

        {_, result, session} =
          execute_step(scope, session_before_run_tests.id, RunTests,
            seed: 1,
            mock_output: "Compilation Error"
          )

        # Verify we got a test failure (undefined module causes runtime error)
        assert result.status == :error

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{result: %{status: :error}}, _, _]
                         }}

        # Write the test files with undefined module error
        write_test_files_with_undefined_module(project_dir)

        # Step 4: Fix Compilation Errors (which fixes the undefined module)
        {_, _, session} =
          execute_step(scope, session.id, FixCompilationErrors,
            mock_output: "Fixed undefined module error"
          )

        # Actually fix the undefined module error
        write_failing_test_module(project_dir)

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{}, _, _, _]
                         }}

        # Step 5: Run Tests Again (passing) - use cached test results
        failing_test_output =
          File.read!(CodeMySpec.Support.TestAdapter.test_results_failing_cache_path())

        {_, result, session} =
          execute_step(scope, session.id, RunTests, seed: 2, mock_output: failing_test_output)

        assert result.status == :ok

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{result: %{status: :ok}}, _, _, _, _]
                         }}

        # Step 6: Finalize
        {_finalize_interaction, _finalize_result, session} =
          execute_step(scope, session.id, Finalize)

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{}, _, _, _, _, _]
                         }}

        # Session should be complete
        assert {:error, :complete} = Sessions.next_command(scope, session.id)
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

  # Write test files with undefined module error to the test project
  defp write_test_files_with_undefined_module(project_dir) do
    # Read fixtures
    test_content = File.read!("test/fixtures/component_test/post_cache_test._ex")

    # Write test file with undefined module error
    test_path =
      Path.join([project_dir, "test", "test_phoenix_project", "blog", "post_cache_test.exs"])

    File.mkdir_p!(Path.dirname(test_path))
    File.write!(test_path, test_content)
  end

  # Fix the undefined module error by replacing with the fixed version
  defp write_failing_test_module(project_dir) do
    fixed_content = File.read!("test/fixtures/component_test/post_cache_test_failing._ex")

    test_path =
      Path.join([project_dir, "test", "test_phoenix_project", "blog", "post_cache_test.exs"])

    File.write!(test_path, fixed_content)
  end
end
