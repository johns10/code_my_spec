defmodule CodeMySpec.StaticAnalysis.Analyzers.DialyzerTest do
  use CodeMySpec.DataCase

  use ExCliVcr
  import CodeMySpec.{UsersFixtures, AccountsFixtures, ProjectsFixtures}

  alias CodeMySpec.StaticAnalysis.Analyzers.Dialyzer
  alias CodeMySpec.Problems.Problem

  # Dialyzer tests can be slow, especially when running actual analysis
  @moduletag timeout: 300_000
  @test_repo_url "https://github.com/johns10/test_phoenix_project.git"

  setup do
    user = user_fixture()
    account = account_with_owner_fixture(user)
    scope = user_scope_fixture(user, account)
    project = project_fixture(scope, %{module_name: "TestPhoenixProject"})
    scope = user_scope_fixture(user, account, project)

    # Clone test project using TestAdapter (include deps for static analysis)
    project_dir =
      "../code_my_spec_test_repos/dialyzer_test_#{System.unique_integer([:positive])}"

    {:ok, ^project_dir} =
      CodeMySpec.Support.TestAdapter.clone(scope, @test_repo_url, project_dir,
        include_deps: true,
        include_git: true
      )

    # Update project with cloned repo path
    {:ok, updated_project} =
      CodeMySpec.Projects.update_project(scope, project, %{code_repo: project_dir})

    scope = user_scope_fixture(user, account, updated_project)

    on_exit(fn ->
      if File.exists?(project_dir) do
        File.rm_rf!(project_dir)
      end
    end)

    %{scope: scope, project: updated_project, project_dir: project_dir}
  end

  # ============================================================================
  # name/0
  # ============================================================================

  describe "name/0" do
    test "returns \"dialyzer\"" do
      assert Dialyzer.name() == "dialyzer"
    end

    test "matches the source field used in generated Problems" do
      warning = dialyzer_warning_fixture()
      problem = CodeMySpec.Problems.ProblemConverter.from_dialyzer(warning)

      assert problem.source == Dialyzer.name()
    end

    test "returns consistent value across calls" do
      first_call = Dialyzer.name()
      second_call = Dialyzer.name()

      assert first_call == second_call
      assert first_call == "dialyzer"
    end
  end

  # ============================================================================
  # available?/1
  # ============================================================================

  describe "available?/1" do
    test "returns true when dialyxir deps directory exists", %{
      scope: scope,
      project_dir: project_dir
    } do
      # Create deps/dialyxir directory to simulate dialyxir being installed
      dialyxir_deps_path = Path.join(project_dir, "deps/dialyxir")
      File.mkdir_p!(dialyxir_deps_path)

      assert Dialyzer.available?(scope) == true
    end

    test "returns false when project directory doesn't exist" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      project = project_fixture(scope, %{code_repo: "/nonexistent"})
      scope = user_scope_fixture(user, account, project)

      assert Dialyzer.available?(scope) == false
    end

    test "does not raise exceptions" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      project = project_fixture(scope, %{code_repo: "/nonexistent"})
      scope = user_scope_fixture(user, account, project)

      result = Dialyzer.available?(scope)
      assert is_boolean(result)
    end

    test "executes quickly without blocking operations", %{scope: scope} do
      {time_microseconds, _result} = :timer.tc(fn -> Dialyzer.available?(scope) end)
      # Should complete in under 100ms (just file checks)
      assert time_microseconds < 100_000
    end

    test "does not modify system state or build PLT", %{project_dir: project_dir, scope: scope} do
      # Create deps/dialyxir to make available? return true
      File.mkdir_p!(Path.join(project_dir, "deps/dialyxir"))

      _result = Dialyzer.available?(scope)

      # Verify no PLT files were created in the project dir
      plt_files = Path.wildcard(Path.join(project_dir, "**/*.plt"))
      assert plt_files == []
    end

    test "returns false when dialyxir dependency not installed", %{
      scope: scope,
      project_dir: project_dir
    } do
      # Remove deps/dialyxir to simulate it being missing
      dialyxir_deps_path = Path.join(project_dir, "deps/dialyxir")
      File.rm_rf!(dialyxir_deps_path)

      assert Dialyzer.available?(scope) == false
    end
  end

  # ============================================================================
  # run/2
  # ============================================================================

  describe "run/2" do
    @tag :slow
    @tag timeout: 300_000
    test "returns {:ok, list(Problem.t())} when Dialyzer executes successfully", %{
      scope: scope,
      project_dir: project_dir
    } do
      use_cmd_cassette "static_analysis_dialyzer_run" do
        {:ok, problems} = Dialyzer.run(scope, cwd: project_dir)

        assert is_list(problems)
        # Dialyzer may return empty list if no type issues found
        Enum.each(problems, fn problem ->
          assert %Problem{} = problem
        end)
      end
    end

    @tag :slow
    @tag timeout: 300_000
    test "each Problem has severity set to :warning", %{scope: scope, project_dir: project_dir} do
      use_cmd_cassette "static_analysis_dialyzer_run" do
        {:ok, problems} = Dialyzer.run(scope, cwd: project_dir)

        Enum.each(problems, fn problem ->
          assert problem.severity == :warning
        end)
      end
    end

    @tag :slow
    @tag timeout: 300_000
    test "each Problem has source_type set to :static_analysis", %{
      scope: scope,
      project_dir: project_dir
    } do
      use_cmd_cassette "static_analysis_dialyzer_run" do
        {:ok, problems} = Dialyzer.run(scope, cwd: project_dir)

        Enum.each(problems, fn problem ->
          assert problem.source_type == :static_analysis
        end)
      end
    end

    @tag :slow
    @tag timeout: 300_000
    test "each Problem has source set to dialyzer", %{scope: scope, project_dir: project_dir} do
      use_cmd_cassette "static_analysis_dialyzer_run" do
        {:ok, problems} = Dialyzer.run(scope, cwd: project_dir)

        Enum.each(problems, fn problem ->
          assert problem.source == "dialyzer"
        end)
      end
    end

    @tag :slow
    @tag timeout: 300_000
    test "each Problem has valid file_path and message", %{scope: scope, project_dir: project_dir} do
      use_cmd_cassette "static_analysis_dialyzer_run" do
        {:ok, problems} = Dialyzer.run(scope, cwd: project_dir)
        assert Enum.count(problems) > 0

        Enum.each(problems, fn problem ->
          assert is_binary(problem.file_path)
          assert String.length(problem.file_path) > 0
          assert is_binary(problem.message)
          assert String.length(problem.message) > 0
        end)
      end
    end

    @tag :slow
    @tag timeout: 300_000
    test "each Problem has category set to type", %{scope: scope, project_dir: project_dir} do
      use_cmd_cassette "static_analysis_dialyzer_run" do
        {:ok, problems} = Dialyzer.run(scope, cwd: project_dir)
        assert Enum.count(problems) > 0

        Enum.each(problems, fn problem ->
          assert problem.category == "type"
        end)
      end
    end

    test "returns {:error, String.t()} when project path does not exist" do
      user = user_fixture()
      account = account_with_owner_fixture(user)
      scope = user_scope_fixture(user, account)
      project = project_fixture(scope, %{code_repo: "/nonexistent"})
      scope = user_scope_fixture(user, account, project)

      nonexistent_path = "/tmp/nonexistent_project_#{System.unique_integer([:positive])}"

      result = Dialyzer.run(scope, cwd: nonexistent_path)

      assert {:error, reason} = result
      assert is_binary(reason)
    end

    @tag timeout: 300_000
    test "respects cwd option to run in specified directory", %{
      scope: scope,
      project_dir: project_dir
    } do
      use_cmd_cassette "static_analysis_dialyzer_run" do
        {:ok, _problems} = Dialyzer.run(scope, cwd: project_dir)
      end
    end
  end

  # ============================================================================
  # Fixtures
  # ============================================================================

  defp dialyzer_warning_fixture(attrs \\ %{}) do
    Enum.into(attrs, %{
      "file" => "lib/my_app/example.ex",
      "line" => 42,
      "type" => :warn_return_no_exit,
      "message" => "Function calculate/2 has no local return."
    })
  end
end
