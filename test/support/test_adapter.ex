defmodule CodeMySpec.Support.TestAdapter do
  @moduledoc """
  Test adapter for Git operations that uses a local fixture repository.

  Maintains a single fixture repository that is cloned once and kept fresh,
  then copies it for each test to avoid network calls and prevent test
  contention from concurrent modifications.
  """

  @behaviour CodeMySpec.Git.Behaviour

  @fixture_path "test_repos/test_phoenix_project"
  @fixture_url "https://github.com/johns10/test_phoenix_project.git"
  @test_results_cache "test_repos/test_results_cache.json"

  @doc """
  Ensures the fixture repository exists and is up to date.

  Clones the repository if it doesn't exist, otherwise pulls latest changes.
  Generates and caches test results if not already cached.
  This should be called once during test setup.
  """
  def ensure_fixture_fresh do
    if File.exists?(@fixture_path) do
      pull_fixture()
    else
      clone_fixture()
    end

    generate_test_results_cache()
  end

  @doc """
  Returns the path to the cached test results JSON file.
  """
  def test_results_cache_path, do: @test_results_cache

  @doc """
  Clones a repository by copying the fixture repo to the destination path.

  This is much faster than actually cloning from a remote and safe for
  concurrent test execution since each test gets its own copy.

  Assumes ensure_fixture_fresh/0 has been called during test setup.
  """
  @impl true
  def clone(_scope, _repo_url, dest_path) do
    case System.cmd("cp", ["-R", @fixture_path, dest_path]) do
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

  defp clone_fixture do
    File.mkdir_p!(Path.dirname(@fixture_path))
    IO.puts("[TestAdapter] Cloning test repository (only happens once)...")

    case System.cmd("git", ["clone", "--recurse-submodules", @fixture_url, @fixture_path],
           stderr_to_stdout: true
         ) do
      {_, 0} ->
        :ok

      {output, code} ->
        raise """
        Failed to clone fixture repository.
        Exit code: #{code}
        Output: #{output}
        """
    end
  end

  defp pull_fixture do
    case System.cmd("git", ["pull"], cd: @fixture_path, stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {output, code} ->
        raise """
        Failed to pull fixture repository.
        Exit code: #{code}
        Output: #{output}
        """
    end
  end

  defp generate_test_results_cache do
    # Only generate if cache doesn't exist
    if should_regenerate_cache?() do
      IO.puts(
        "\n[TestAdapter] Generating test results cache (this happens once per fixture update)..."
      )

      # Install dependencies
      IO.puts("[TestAdapter] Installing dependencies...")
      System.cmd("mix", ["deps.get"], cd: @fixture_path, stderr_to_stdout: true)

      # Run tests and write JSON to file
      IO.puts("[TestAdapter] Running tests...")
      test_results_file = "test_results.json"

      # env inherits all vars and overrides/adds those specified
      System.cmd("mix", ["test", "--formatter", "ExUnitJsonFormatter"],
        cd: @fixture_path,
        stderr_to_stdout: true,
        env: [{"EXUNIT_JSON_OUTPUT_FILE", test_results_file}]
      )

      # Copy test results to cache location
      IO.puts("[TestAdapter] Caching test results...")
      File.mkdir_p!(Path.dirname(@test_results_cache))
      File.cp!(Path.join(@fixture_path, test_results_file), @test_results_cache)

      # Remove deps and test results file to keep directory size down
      IO.puts("[TestAdapter] Cleaning up dependencies...")
      File.rm_rf!(Path.join(@fixture_path, "deps"))
      File.rm_rf!(Path.join(@fixture_path, "_build"))
      test_results_path = Path.join(@fixture_path, test_results_file)
      File.rm!(test_results_path)

      IO.puts("[TestAdapter] Cache generation complete!\n")
    end
  end

  defp should_regenerate_cache? do
    # Only regenerate if cache doesn't exist
    # We rely on manual cache deletion if fixture repo needs updating
    not File.exists?(@test_results_cache)
  end
end
