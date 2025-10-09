defmodule CodeMySpec.Support.TestAdapter do
  @moduledoc """
  Test adapter for Git operations that uses a local fixture repository.

  Maintains a single fixture repository that is cloned once and kept fresh,
  then copies it for each test to avoid network calls and prevent test
  contention from concurrent modifications.
  """

  @behaviour CodeMySpec.Git.Behaviour

  @code_repo_fixture_path "test_repos/test_phoenix_project"
  @content_repo_fixture_path "test_repos/test_content_repo"
  @code_fixture_url "https://github.com/johns10/test_phoenix_project.git"
  @content_fixture_url "https://github.com/johns10/test_content_repo.git"
  @test_results_cache "test_repos/test_results_cache.json"
  @test_results_failing_cache "test_repos/test_results_failing_cache.json"

  @doc """
  Ensures the fixture repositories exist and are up to date.

  Clones the repositories if they don't exist, otherwise pulls latest changes.
  Generates and caches test results if not already cached.
  This should be called once during test setup.
  """
  def ensure_fixture_fresh do
    ensure_repo_fresh(@code_repo_fixture_path, @code_fixture_url)
    ensure_repo_fresh(@content_repo_fixture_path, @content_fixture_url)
    generate_test_results_caches()
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
  Clones a repository by copying the fixture repo to the destination path.

  Matches on the repo URL to determine which fixture to use (code vs content).
  This is much faster than actually cloning from a remote and safe for
  concurrent test execution since each test gets its own copy.

  Assumes ensure_fixture_fresh/0 has been called during test setup.
  """
  @impl true
  def clone(_scope, repo_url, dest_path) do
    fixture_path = select_fixture(repo_url)

    # Copy contents of fixture into dest_path (not the fixture directory itself)
    # Using shell glob to copy all files including hidden ones
    case System.cmd("sh", ["-c", "cp -R #{fixture_path}/. #{dest_path}/"]) do
      {_, 0} ->
        {:ok, dest_path}

      {output, _code} ->
        {:error, "Failed to copy fixture: #{output}"}
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
    case System.cmd("git", ["pull"], cd: fixture_path, stderr_to_stdout: true) do
      {_, 0} ->
        :ok

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
    if should_regenerate_cache?() do
      IO.puts(
        "\n[TestAdapter] Generating test results caches (this happens once per fixture update)..."
      )

      # Install dependencies
      IO.puts("[TestAdapter] Installing dependencies...")
      System.cmd("mix", ["deps.get"], cd: @code_repo_fixture_path, stderr_to_stdout: true)

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
      failing_test_content = File.read!("test/fixtures/component_coding/blog_repository_test._ex")
      test_path =
        Path.join([
          @code_repo_fixture_path,
          "test",
          "test_phoenix_project",
          "blog",
          "blog_repository_test.exs"
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

      # Remove the failing test file
      IO.puts("[TestAdapter] Cleaning up failing test file...")
      File.rm!(test_path)

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

  defp should_regenerate_cache? do
    # Only regenerate if cache doesn't exist
    # We rely on manual cache deletion if fixture repo needs updating
    not File.exists?(@test_results_cache)
  end
end
