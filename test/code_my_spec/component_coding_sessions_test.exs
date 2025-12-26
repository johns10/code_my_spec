defmodule CodeMySpec.ComponentCodingSessionsTest do
  alias CodeMySpec.Sessions.Interaction
  use CodeMySpec.DataCase
  import CodeMySpec.Support.CLIRecorder
  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures}
  alias CodeMySpec.{Sessions, Components}
  alias CodeMySpec.ComponentCodingSessions

  alias CodeMySpec.ComponentCodingSessions.Steps.{
    Finalize,
    FixTestFailures,
    GenerateImplementation,
    Initialize,
    RunTests
  }

  @test_repo_url "https://github.com/johns10/test_phoenix_project.git"

  describe "component coding session workflow" do
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

      # Create test component to implement (PostRepository)
      {:ok, post_repository} =
        Components.create_component(scope, %{
          name: "PostRepository",
          type: :repository,
          module_name: "TestPhoenixProject.Blog.PostRepository",
          description: "Repository for blog persistence",
          parent_component_id: blog_context.id
        })

      %{scope: scope, blog_context: blog_context, post_repository: post_repository}
    end

    @tag timeout: 300_000
    # @tag :integration
    test "executes complete component coding workflow", %{
      scope: scope,
      post_repository: post_repository
    } do
      project_dir =
        "../code_my_spec_test_repos/component_coding_session_#{System.unique_integer([:positive])}"

      # Setup test project using TestAdapter
      {:ok, ^project_dir} =
        CodeMySpec.Support.TestAdapter.clone(scope, @test_repo_url, project_dir)

      CodeMySpec.Sessions.subscribe_sessions(scope)

      # Use CLI recorder for the session
      use_cassette "component_coding_workflow" do
        # Create component coding session
        {:ok, session} =
          Sessions.create_session(scope, %{
            type: ComponentCodingSessions,
            agent: :claude_code,
            environment: :local,
            component_id: post_repository.id
          })

        # Step 1: Initialize
        {_, _, session} = execute_step(scope, session.id, Initialize)
        assert_received {:updated, %CodeMySpec.Sessions.Session{interactions: [%Interaction{}]}}

        # Step 4: Generate Implementation
        {_, _, session} =
          execute_step(
            scope,
            session.id,
            GenerateImplementation,
            mock_output: "Generated implementation for PostRepository"
          )

        # Write the actual files that would have been generated
        write_implementation_files(project_dir)

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [%Interaction{}, _]}}

        # Step 5: Run Tests (with failures) - use cached test results
        failing_test_output =
          File.read!(CodeMySpec.Support.TestAdapter.test_results_failing_cache_path())

        {_, result, session} =
          execute_step(scope, session.id, RunTests, seed: 1, mock_output: failing_test_output)

        # Verify we got a failure
        assert result.status == :error
        assert result.data["stats"]["failures"] == 2

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{result: %{status: :error}}, _, _]
                         }}

        # Step 6: Fix Test Failures
        {_, _, session} =
          execute_step(scope, session.id, FixTestFailures, mock_output: "Fixed test failures")

        # Actually fix the test file
        fix_test_file(project_dir)

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{}, _, _, _]
                         }}

        # Step 7: Run Tests Again (passing) - use cached test results
        passing_test_output = File.read!(CodeMySpec.Support.TestAdapter.test_results_cache_path())

        {_, result, session} =
          execute_step(scope, session.id, RunTests, seed: 2, mock_output: passing_test_output)

        # Verify tests now pass
        assert result.status == :ok
        assert result.data["stats"]["failures"] == 0

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{result: %{status: :ok}}, _, _, _, _]
                         }}

        # Step 8: Finalize
        {_finalize_interaction, _finalize_result, session} =
          execute_step(scope, session.id, Finalize)

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{}, _, _, _, _, _]
                         }}

        # Session should be complete
        assert {:error, :complete} = Sessions.next_command(scope, session.id)

        File.rm_rf(project_dir)
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

  # Write implementation and test files to the test project
  defp write_implementation_files(project_dir) do
    # Read fixtures
    impl_content = File.read!("test/fixtures/component_coding/post_repository._ex")
    test_content = File.read!("test/fixtures/component_coding/post_repository_test._ex")

    # Write implementation file
    impl_path =
      Path.join([project_dir, "lib", "test_phoenix_project", "blog", "post_repository.ex"])

    File.mkdir_p!(Path.dirname(impl_path))
    File.write!(impl_path, impl_content)

    # Write test file
    test_path =
      Path.join([project_dir, "test", "test_phoenix_project", "blog", "post_repository_test.exs"])

    File.mkdir_p!(Path.dirname(test_path))
    File.write!(test_path, test_content)
  end

  # Fix the test file by replacing with the passing version
  defp fix_test_file(project_dir) do
    fixed_content = File.read!("test/fixtures/component_coding/post_repository_test_fixed._ex")

    test_path =
      Path.join([project_dir, "test", "test_phoenix_project", "blog", "post_repository_test.exs"])

    File.write!(test_path, fixed_content)
  end
end
