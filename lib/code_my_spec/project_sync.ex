defmodule CodeMySpec.ProjectSync do
  @moduledoc """
  Public API for orchestrating synchronization of the entire project from filesystem
  to database and maintaining real-time sync via file watching.

  This is the public interface module following the Dave Thomas pattern:

  - **ProjectSync** (this module) - Public API
  - **ProjectSync.Sync** - Synchronization implementation (all sync logic)
  - **ProjectSync.ChangeHandler** - Routes file changes to sync operations
  - **ProjectSync.FileWatcherServer** - GenServer managing FileSystem watcher (singleton)
  """

  alias CodeMySpec.Users.Scope
  alias CodeMySpec.ProjectSync.{Sync, FileWatcherServer}

  @type sync_result :: %{
          contexts: [CodeMySpec.Components.Component.t()],
          requirements_updated: integer(),
          errors: [term()]
        }

  @doc """
  Performs a complete project synchronization at startup.

  Delegates to `Sync.sync_all/2`.

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
    Sync.sync_all(scope, opts)
  end

  @doc """
  Starts the singleton file watcher server process.

  Delegates to `FileWatcherServer.start_link/1`.

  Note: This is typically called by the application supervisor at startup, not manually.

  ## Returns
    - `{:ok, pid}` on success
    - `{:error, {:already_started, pid}}` if already running
  """
  @spec start_watching() :: {:ok, pid()} | {:error, term()}
  def start_watching do
    FileWatcherServer.start_link([])
  end

  @doc """
  Stops the singleton file watcher server process.

  Delegates to `GenServer.stop/1`.

  ## Returns
    - `:ok`
  """
  @spec stop_watching() :: :ok
  def stop_watching do
    GenServer.stop(FileWatcherServer)
  end
end
