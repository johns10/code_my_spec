defmodule CodeMySpec.Support.TestAdapter do
  @moduledoc """
  Test adapter for Git operations that uses a local fixture repository.

  Maintains a single fixture repository that is cloned once and kept fresh,
  then copies it for each test to avoid network calls and prevent test
  contention from concurrent modifications.
  """

  @behaviour CodeMySpec.Git.Behaviour

  @code_repo_fixture_path "../code_my_spec_test_repos/test_phoenix_project"
  @content_repo_fixture_path "../code_my_spec_test_repos/test_content_repo"
  @code_fixture_url "https://github.com/johns10/test_phoenix_project.git"
  @content_fixture_url "https://github.com/johns10/test_content_repo.git"
  @test_results_cache "../code_my_spec_test_repos/test_results_cache.json"
  @test_results_failing_cache "../code_my_spec_test_repos/test_results_failing_cache.json"
  @test_results_post_cache_failing_cache "../code_my_spec_test_repos/test_results_post_cache_failing_cache.json"
  @compiler_ok_cache "../code_my_spec_test_repos/compiler_ok_cache.json"
  @compiler_warnings_cache "../code_my_spec_test_repos/compiler_warnings_cache.json"
  @compiler_errors_cache "../code_my_spec_test_repos/compiler_errors_cache.json"

  @doc """
  Ensures the fixture repositories exist and are up to date.

  Clones the repositories if they don't exist, otherwise pulls latest changes.
  Generates and caches test results and compiler diagnostics if not already cached.
  This should be called once during test setup.
  """
  def ensure_fixture_fresh do
    ensure_repo_fresh(@code_repo_fixture_path, @code_fixture_url)
    ensure_repo_fresh(@content_repo_fixture_path, @content_fixture_url)

    if !File.exists?(@compiler_ok_cache) or !File.exists?(@compiler_warnings_cache) or
         !File.exists?(@compiler_errors_cache) or !File.exists?(@test_results_cache) or
         !File.exists?(@test_results_failing_cache) or
         !File.exists?(@test_results_post_cache_failing_cache) do
      IO.puts("[TestAdapter] Installing dependencies...")
      System.cmd("mix", ["deps.get"], cd: @code_repo_fixture_path, stderr_to_stdout: true)
    end

    generate_compiler_caches()
    generate_test_results_caches()
    generate_post_cache_failing_tests()
  end

  @doc """
  Returns the path to the cached test results JSON file.
  """
  def test_results_cache_path, do: @test_results_cache

  @doc """
  Returns the path to the cached failing test results JSON file.
  """
  def test_results_failing_cache_path, do: @test_results_failing_cache

  @doc """
  Returns the path to the cached post cache failing test results JSON file.
  """
  def test_results_post_cache_failing_cache_path, do: @test_results_post_cache_failing_cache

  @doc """
  Returns the path to the cached clean compilation results JSON file.
  """
  def compiler_ok_cache_path, do: @compiler_ok_cache

  @doc """
  Returns the path to the cached compilation warnings results JSON file.
  """
  def compiler_warnings_cache_path, do: @compiler_warnings_cache

  @doc """
  Returns the path to the cached compilation errors results JSON file.
  """
  def compiler_errors_cache_path, do: @compiler_errors_cache

  @doc """
  Clones a repository by copying the fixture repo to the destination path.

  Matches on the repo URL to determine which fixture to use (code vs content).
  This is much faster than actually cloning from a remote and safe for
  concurrent test execution since each test gets its own copy.

  Assumes ensure_fixture_fresh/0 has been called during test setup.
  """
  @impl true
  def clone(_scope, repo_url, dest_path) do
    fixture_path = select_fixture(repo_url)

    # Create destination directory
    File.mkdir_p!(dest_path)

    # Copy contents of fixture into dest_path, excluding .git directory
    # We don't need git history for tests, just the files
    case System.cmd("sh", ["-c", "rsync -a --exclude='.git' #{fixture_path}/ #{dest_path}/"]) do
      {_, 0} ->
        {:ok, dest_path}

      {output, code} ->
        {:error, "Failed to copy fixture: #{output}, #{code}"}
    end
  end

  @doc """
  Simulates a pull operation.

  Since tests use copies of the fixture, pull operations are no-ops.
  Returns :ok to satisfy the behaviour contract.
  """
  @impl true
  def pull(_scope, _path) do
    :ok
  end

  defp select_fixture(repo_url) do
    cond do
      String.contains?(repo_url, "test_content_repo") -> @content_repo_fixture_path
      String.contains?(repo_url, "test_phoenix_project") -> @code_repo_fixture_path
      # Default to code repo for backward compatibility
      true -> @code_repo_fixture_path
    end
  end

  defp ensure_repo_fresh(fixture_path, fixture_url) do
    if File.exists?(fixture_path) do
      pull_repo(fixture_path)
    else
      clone_repo(fixture_path, fixture_url)
    end
  end

  defp clone_repo(fixture_path, fixture_url) do
    File.mkdir_p!(Path.dirname(fixture_path))
    IO.puts("[TestAdapter] Cloning #{fixture_url} (only happens once)...")

    case System.cmd(
           "git",
           ["clone", "--recurse-submodules", fixture_url, fixture_path],
           stderr_to_stdout: true
         ) do
      {_, 0} ->
        :ok

      {output, code} ->
        raise """
        Failed to clone fixture repository.
        URL: #{fixture_url}
        Exit code: #{code}
        Output: #{output}
        """
    end
  end

  defp pull_repo(fixture_path) do
    case System.cmd("git", ["pull", "--recurse-submodules"],
           cd: fixture_path,
           stderr_to_stdout: true
         ) do
      {_, 0} ->
        # Also update submodules after pull
        case System.cmd("git", ["submodule", "update", "--init", "--recursive"],
               cd: fixture_path,
               stderr_to_stdout: true
             ) do
          {_, 0} ->
            :ok

          {output, code} ->
            raise """
            Failed to update submodules.
            Path: #{fixture_path}
            Exit code: #{code}
            Output: #{output}
            """
        end

      {output, code} ->
        raise """
        Failed to pull fixture repository.
        Path: #{fixture_path}
        Exit code: #{code}
        Output: #{output}
        """
    end
  end

  defp generate_test_results_caches do
    # Only generate if cache doesn't exist
    if not File.exists?(@test_results_cache) do
      # Run tests and write JSON to file (passing tests)
      IO.puts("[TestAdapter] Running passing tests...")
      test_results_file = "test_results.json"

      # env inherits all vars and overrides/adds those specified
      System.cmd("mix", ["test", "--formatter", "ExUnitJsonFormatter"],
        cd: @code_repo_fixture_path,
        stderr_to_stdout: true,
        env: [{"EXUNIT_JSON_OUTPUT_FILE", test_results_file}]
      )

      # Copy test results to cache location
      IO.puts("[TestAdapter] Caching passing test results...")
      File.mkdir_p!(Path.dirname(@test_results_cache))
      File.cp!(Path.join(@code_repo_fixture_path, test_results_file), @test_results_cache)

      # Remove test results file
      test_results_path = Path.join(@code_repo_fixture_path, test_results_file)
      File.rm!(test_results_path)

      # Now generate failing test cache
      IO.puts("[TestAdapter] Setting up failing test...")
      failing_test_content = File.read!("test/fixtures/component_coding/post_repository_test._ex")

      test_path =
        Path.join([
          @code_repo_fixture_path,
          "test",
          "test_phoenix_project",
          "blog",
          "post_repository_test.exs"
        ])

      File.mkdir_p!(Path.dirname(test_path))
      File.write!(test_path, failing_test_content)

      # Run tests with failing test
      IO.puts("[TestAdapter] Running tests with failing test...")
      test_results_failing_file = "test_results_failing.json"

      System.cmd("mix", ["test", "--formatter", "ExUnitJsonFormatter"],
        cd: @code_repo_fixture_path,
        stderr_to_stdout: true,
        env: [{"EXUNIT_JSON_OUTPUT_FILE", test_results_failing_file}]
      )

      # Copy failing test results to cache location
      IO.puts("[TestAdapter] Caching failing test results...")
      File.mkdir_p!(Path.dirname(@test_results_failing_cache))

      File.cp!(
        Path.join(@code_repo_fixture_path, test_results_failing_file),
        @test_results_failing_cache
      )

      # Restore the original test file from git
      IO.puts("[TestAdapter] Restoring original test file from git...")

      System.cmd("git", ["restore", "test/test_phoenix_project/blog/post_repository_test.exs"],
        cd: @code_repo_fixture_path,
        stderr_to_stdout: true
      )

      # Remove failing test results file
      test_results_failing_path = Path.join(@code_repo_fixture_path, test_results_failing_file)
      File.rm!(test_results_failing_path)

      # Remove deps and build to keep directory size down
      IO.puts("[TestAdapter] Cleaning up dependencies...")
      File.rm_rf!(Path.join(@code_repo_fixture_path, "deps"))
      File.rm_rf!(Path.join(@code_repo_fixture_path, "_build"))

      IO.puts("[TestAdapter] Cache generation complete!\n")
    end
  end

  defp generate_post_cache_failing_tests do
    # Only generate if cache doesn't exist
    if not File.exists?(@test_results_post_cache_failing_cache) do
      IO.puts("[TestAdapter] Setting up post cache failing tests...")

      # Read the fixture test file
      failing_test_content = File.read!("test/fixtures/component_coding/post_cache_test._ex")

      # Determine the target test path in the fixture repo
      test_path =
        Path.join([
          @code_repo_fixture_path,
          "test",
          "test_phoenix_project",
          "blog",
          "post_cache_test.exs"
        ])

      # Ensure the directory exists and write the test file
      File.mkdir_p!(Path.dirname(test_path))
      File.write!(test_path, failing_test_content)

      # Run tests with the post cache test (all should fail)
      IO.puts("[TestAdapter] Running post cache tests (expecting failures)...")
      test_results_file = "test_results_post_cache_failing.json"

      System.cmd(
        "mix",
        [
          "test",
          "test/test_phoenix_project/blog/post_cache_test.exs",
          "--formatter",
          "ExUnitJsonFormatter"
        ],
        cd: @code_repo_fixture_path,
        stderr_to_stdout: true,
        env: [{"EXUNIT_JSON_OUTPUT_FILE", test_results_file}]
      )

      # Copy test results to cache location
      IO.puts("[TestAdapter] Caching post cache failing test results...")
      File.mkdir_p!(Path.dirname(@test_results_post_cache_failing_cache))

      File.cp!(
        Path.join(@code_repo_fixture_path, test_results_file),
        @test_results_post_cache_failing_cache
      )

      # Clean up the test file (remove it since it shouldn't be in the repo)
      IO.puts("[TestAdapter] Cleaning up post cache test file...")
      File.rm!(test_path)

      # Remove test results file
      test_results_path = Path.join(@code_repo_fixture_path, test_results_file)
      File.rm!(test_results_path)

      IO.puts("[TestAdapter] Post cache failing test cache generation complete!")
    end
  end

  defp generate_compiler_caches do
    # Expand paths to absolute paths
    code_repo_fixture_abs = Path.expand(@code_repo_fixture_path)

    warnings_file_path = Path.join([code_repo_fixture_abs, "lib", "warnings.ex"])
    errors_file_path = Path.join([code_repo_fixture_abs, "lib", "errors.ex"])

    # Expand cache paths to absolute paths
    compiler_ok_cache_abs = Path.expand(@compiler_ok_cache)
    compiler_warnings_cache_abs = Path.expand(@compiler_warnings_cache)
    compiler_errors_cache_abs = Path.expand(@compiler_errors_cache)

    if not File.exists?(@compiler_ok_cache) do
      # 1. Generate clean compilation cache
      IO.puts("[TestAdapter] Generating clean compilation cache...")

      # Clean build to ensure fresh compilation
      File.rm_rf!(Path.join(code_repo_fixture_abs, "_build"))

      result = CodeMySpec.Compile.execute(cwd: code_repo_fixture_abs)
      File.cp!(result.output_file, compiler_ok_cache_abs)

      if !File.exists?(compiler_ok_cache_abs), do: raise("Compiler OK cache failed to be created")
    end

    if not File.exists?(@compiler_warnings_cache) do
      # 2. Generate compilation warnings cache
      IO.puts("[TestAdapter] Generating compilation warnings cache...")

      # Copy warnings fixture to lib/warnings.ex
      warnings_fixture = "test/fixtures/compiler/post_repository_warnings._ex"
      File.cp!(warnings_fixture, warnings_file_path)

      # Clean and recompile to get warnings
      File.rm_rf!(Path.join(code_repo_fixture_abs, "_build"))

      result = CodeMySpec.Compile.execute(cwd: code_repo_fixture_abs)
      File.cp!(result.output_file, compiler_warnings_cache_abs)

      if !File.exists?(compiler_warnings_cache_abs),
        do: raise("Compiler warnings cache failed to be created")

      # Delete warnings file
      File.rm!(warnings_file_path)
    end

    if not File.exists?(@compiler_errors_cache) do
      # 3. Generate compilation errors cache
      IO.puts("[TestAdapter] Generating compilation errors cache...")

      # Copy errors fixture to lib/errors.ex
      errors_fixture = "test/fixtures/compiler/post_repository_errors._ex"
      File.cp!(errors_fixture, errors_file_path)

      # Clean and recompile to get errors
      File.rm_rf!(Path.join(code_repo_fixture_abs, "_build"))

      result = CodeMySpec.Compile.execute(cwd: code_repo_fixture_abs)
      File.cp!(result.output_file, compiler_errors_cache_abs)

      if !File.exists?(compiler_errors_cache_abs),
        do: raise("Compiler errors cache failed to be created")

      # Delete errors file
      File.rm!(errors_file_path)

      # Clean build directory one final time
      File.rm_rf!(Path.join(code_repo_fixture_abs, "_build"))
    end

    IO.puts("[TestAdapter] Compiler cache generation complete!")
  end
end
