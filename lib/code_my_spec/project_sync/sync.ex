defmodule CodeMySpec.ProjectSync.Sync do
  @moduledoc """
  Implementation module that performs the actual synchronization logic.

  This is a pure functional module with no state - all functions perform
  synchronization operations (DB operations, file system operations).
  """

  alias CodeMySpec.Users.Scope
  alias CodeMySpec.Components
  alias CodeMySpec.ProjectCoordinator
  alias CodeMySpec.Tests.TestRun
  alias CodeMySpec.Utils.Paths

  @type sync_result :: %{
          contexts: [Components.Component.t()],
          requirements_updated: integer(),
          errors: [term()],
          timings: %{
            contexts_sync_ms: integer(),
            requirements_sync_ms: integer(),
            total_ms: integer()
          }
        }

  @doc """
  Performs a complete project synchronization.

  ## Process
  1. Syncs all contexts and their components
  2. Gets current file list from filesystem
  3. Gets latest test results (or empty test run if none exist)
  4. Analyzes and updates all component requirements
  5. Returns consolidated sync statistics

  ## Parameters
    - `scope` - The user scope
    - `opts` - Options (optional)
      - `:base_dir` - Base directory to sync from (defaults to current working directory)

  ## Returns
    - `{:ok, sync_result}` on success
    - `{:error, reason}` on failure
  """
  @spec sync_all(Scope.t(), keyword()) :: {:ok, sync_result()} | {:error, term()}
  def sync_all(%Scope{} = scope, opts \\ []) do
    total_start = System.monotonic_time(:millisecond)
    base_dir = Keyword.get(opts, :base_dir, File.cwd!())

    # Time context sync
    contexts_start = System.monotonic_time(:millisecond)

    with {:ok, contexts_result} <- Components.Sync.sync_contexts(scope, base_dir: base_dir) do
      contexts_sync_ms = System.monotonic_time(:millisecond) - contexts_start

      # Time requirements sync
      requirements_start = System.monotonic_time(:millisecond)
      file_list = get_file_list(base_dir)
      test_run = get_latest_test_run(base_dir)

      # Sync project requirements - pass opts through for persist control
      _components = ProjectCoordinator.sync_project_requirements(scope, file_list, test_run, opts)
      requirements_sync_ms = System.monotonic_time(:millisecond) - requirements_start

      total_ms = System.monotonic_time(:millisecond) - total_start

      {:ok,
       %{
         contexts: contexts_result,
         requirements_updated: 0,
         errors: [],
         timings: %{
           contexts_sync_ms: contexts_sync_ms,
           requirements_sync_ms: requirements_sync_ms,
           total_ms: total_ms
         }
       }}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Synchronizes a context when any of its files change (spec or implementation).

  ## Process
  1. Uses Paths utilities to derive the spec path from any file
  2. Syncs the context record and components
  3. Recalculates ALL project requirements (contexts have dependencies)

  ## Parameters
    - `scope` - The user scope
    - `file_path` - Path to the changed file

  ## Returns
    - `:ok` on success
    - `{:error, reason}` on failure
  """
  @spec sync_context(Scope.t(), file_path :: String.t()) ::
          :ok | {:error, term()}
  def sync_context(%Scope{} = scope, file_path) do
    with {:ok, spec_path} <- Paths.spec_path(file_path),
         {:ok, _context} <- Components.Sync.sync_context(scope, spec_path),
         :ok <- recalculate_requirements(scope) do
      :ok
    else
      {:error, :not_a_context_path} ->
        # Not a context file - orphaned file, not an error
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Recalculates all component requirements after a sync operation.

  ## Parameters
    - `scope` - The user scope

  ## Returns
    - `:ok` on success
    - `{:error, reason}` on failure
  """
  @spec recalculate_requirements(Scope.t()) :: :ok | {:error, term()}
  def recalculate_requirements(%Scope{} = scope) do
    file_list = get_file_list()
    test_run = get_latest_test_run()

    _components = ProjectCoordinator.sync_project_requirements(scope, file_list, test_run, [])

    :ok
  end

  # Private Functions

  # Gets the list of all files in the project
  defp get_file_list(base_dir \\ nil) do
    project_root = base_dir || File.cwd!()

    # Recursively list all files, excluding common directories
    # Return paths relative to project root
    Path.wildcard("#{project_root}/**/*")
    |> Enum.reject(fn path ->
      String.contains?(path, ["deps/", "_build/", ".git/", "node_modules/"])
    end)
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, project_root))
  end

  # Gets the latest test run, or creates an empty one if none exists
  defp get_latest_test_run(base_dir \\ nil) do
    project_root = base_dir || File.cwd!()

    # For now, return an empty test run
    # In the future, this could query from a TestRuns context/repository
    %TestRun{
      failures: [],
      project_path: project_root,
      command: "",
      execution_status: :success,
      raw_output: "",
      executed_at: NaiveDateTime.utc_now()
    }
  end
end
