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
          type: "context",
          module_name: "TestPhoenixProject.Blog",
          description: "Blog context for managing posts"
        })

      # Create test component to test (PostCache)
      {:ok, post_cache} =
        Components.create_component(scope, %{
          name: "PostCache",
          type: "genserver",
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
      project_dir =
        "../code_my_spec_test_repos/component_test_session_#{System.unique_integer([:positive])}"

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
            environment: :cli,
            component_id: post_cache.id,
            state: %{working_dir: project_dir}
          })

        # Step 1: Initialize
        {_, _, session} = execute_step(scope, session.id, Initialize)
        assert_received {:updated, %CodeMySpec.Sessions.Session{interactions: [%Interaction{}]}}

        # Step 2: GenerateTestsAndFixtures (async)
        {:ok, session} = Sessions.execute(scope, session.id)
        [interaction | _] = session.interactions
        assert interaction.command.module == GenerateTestsAndFixtures

        # Write the test files that would have been generated
        write_test_files_with_undefined_module(project_dir)

        # Complete the async interaction
        {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, %{status: :ok})

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{interactions: [%Interaction{}, _]}}

        # Step 3: RunTests (async - should fail with undefined module error)
        {:ok, session} = Sessions.execute(scope, session.id)
        [interaction | _] = session.interactions
        assert interaction.command.module == RunTests

        # Mock test failure result with clean compilation and failing tests
        compiler_errors = File.read!(CodeMySpec.Support.TestAdapter.compiler_errors_cache_path())

        test_failure_result = %{
          status: :error,
          data: %{
            compiler_results: compiler_errors,
            test_results: %{}
          }
        }

        # Complete the async interaction with error result
        {:ok, session} =
          Sessions.handle_result(scope, session.id, interaction.id, test_failure_result)

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{result: %{status: :error}}, _, _]
                         }}

        # Step 4: FixCompilationErrors (async)
        {:ok, session} = Sessions.execute(scope, session.id)
        [interaction | _] = session.interactions
        assert interaction.command.module == FixCompilationErrors

        # Actually fix the undefined module error
        write_failing_test_module(project_dir)

        # Complete the async interaction
        {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, %{status: :ok})

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{}, _, _, _]
                         }}

        # Step 5: RunTests Again (async - should pass now)
        {:ok, session} = Sessions.execute(scope, session.id)
        [interaction | _] = session.interactions
        assert interaction.command.module == RunTests

        compiler_ok = File.read!(CodeMySpec.Support.TestAdapter.compiler_ok_cache_path())

        post_cache_test_output =
          File.read!(CodeMySpec.Support.TestAdapter.test_results_post_cache_failing_cache_path())

        # Mock successful test result with clean compilation and failing tests
        test_success_result = %{
          status: :ok,
          data: %{
            compiler_results: compiler_ok,
            test_results: post_cache_test_output
          },
          exit_code: 0
        }

        test_path =
          Path.join([
            project_dir,
            "test",
            "test_phoenix_project",
            "blog",
            "post_cache_test.exs"
          ])

        File.cp("test/fixtures/component_coding/post_cache_test._ex", test_path)

        # Complete the async interaction with success result
        {:ok, session} =
          Sessions.handle_result(scope, session.id, interaction.id, test_success_result,
            cwd: project_dir
          )

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{result: %{status: :ok}}, _, _, _, _]
                         }}

        # Step 6: Finalize (async)
        {:ok, session} = Sessions.execute(scope, session.id)
        [interaction | _] = session.interactions
        assert interaction.command.module == Finalize

        # Complete the async interaction
        {:ok, session} = Sessions.handle_result(scope, session.id, interaction.id, %{status: :ok})

        assert_received {:updated,
                         %CodeMySpec.Sessions.Session{
                           interactions: [%Interaction{}, _, _, _, _, _]
                         }}

        # Session should be complete
        assert {:error, :complete} = Sessions.execute(scope, session.id)
      end
    end
  end

  # Helper function to execute a session step with common pattern
  defp execute_step(scope, session_id, expected_module, opts \\ []) do
    {:ok, session} = Sessions.execute(scope, session_id, opts)
    [interaction | _] = session.interactions
    assert interaction.command.module == expected_module

    final_result = Map.get(interaction, :result)

    {interaction, final_result, session}
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
