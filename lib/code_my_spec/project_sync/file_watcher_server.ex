defmodule CodeMySpec.ProjectSync.FileWatcherServer do
  @moduledoc """
  Singleton GenServer that manages the FileSystem watcher process and debounces file change events.

  This module integrates with the `FileSystem` library to watch for file changes.
  There is only ONE instance of this server per application.
  """
  use GenServer
  require Logger

  alias CodeMySpec.Users.Scope
  alias CodeMySpec.ProjectSync.{ChangeHandler, Sync}

  @type state :: %{
          watcher_pid: pid() | nil,
          debounce_timer: reference() | nil,
          pending_changes: MapSet.t(String.t()),
          running: boolean()
        }

  # Client API

  @doc """
  Starts the singleton file watcher server.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns whether the file watcher is currently running.
  """
  @spec running?() :: boolean()
  def running? do
    GenServer.call(__MODULE__, :running?)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    project_root = File.cwd!()
    spec_dir = Path.join(project_root, "docs/spec")
    lib_dir = Path.join(project_root, "lib")

    case FileSystem.start_link(dirs: [spec_dir, lib_dir]) do
      {:ok, watcher_pid} ->
        FileSystem.subscribe(watcher_pid)

        # Subscribe to user channel to listen for project initialization events
        Phoenix.PubSub.subscribe(CodeMySpec.PubSub, "user:*")

        Logger.info("FileWatcherServer started, watching: #{spec_dir}, #{lib_dir}")

        {:ok,
         %{
           watcher_pid: watcher_pid,
           debounce_timer: nil,
           pending_changes: MapSet.new(),
           running: true
         }, {:continue, :initial_sync}}

      {:error, reason} ->
        Logger.error("Failed to start FileSystem watcher: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:initial_sync, state) do
    Logger.info("FileWatcherServer performing initial sync_all")
    broadcast_status_change(true)

    Process.sleep(1000)

    with %Scope{} = scope <- Scope.for_cli(),
         {:ok, _result} <- Sync.sync_all(scope, persist: true, environment_type: :cli) do
      Logger.info("Initial sync completed for project #{scope.active_project_id}")
    end

    broadcast_status_change(false)

    {:noreply, %{state | running: false}}
  end

  @impl true
  def handle_call(:running?, _from, state) do
    {:reply, state.running, state}
  end

  @impl true
  def handle_info({:file_event, _watcher_pid, {path, _events}}, state) do
    # Add path to pending changes
    pending_changes = MapSet.put(state.pending_changes, path)

    # Cancel existing timer if present
    if state.debounce_timer do
      Process.cancel_timer(state.debounce_timer)
    end

    # Start new debounce timer (100ms)
    timer_ref = Process.send_after(self(), :process_changes, 100)

    {:noreply, %{state | pending_changes: pending_changes, debounce_timer: timer_ref}}
  end

  @impl true
  def handle_info(:process_changes, state) do
    # Process all pending changes
    state.pending_changes
    |> Enum.each(fn path ->
      scope = Scope.for_cli()

      case ChangeHandler.handle_file_change(scope, path, [:modified]) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.error(
            "Failed to sync file #{path} for scope #{scope.active_project_id}: #{inspect(reason)}"
          )
      end
    end)

    # Clear pending changes and timer
    {:noreply, %{state | pending_changes: MapSet.new(), debounce_timer: nil}}
  end

  @impl true
  def handle_info({:project_initialized, _data}, state) do
    Logger.info("FileWatcherServer received project_initialized event, syncing project")
    broadcast_status_change(true)

    with %Scope{} = scope <- Scope.for_cli(),
         {:ok, _result} <- Sync.sync_all(scope, persist: true, environment_type: :cli) do
      Logger.info("Project sync completed for project #{scope.active_project_id}")
    end

    broadcast_status_change(false)

    {:noreply, %{state | running: false}}
  end

  @impl true
  def handle_info({:file_event, _watcher_pid, :stop}, state) do
    Logger.warning("FileSystem watcher stopped")

    # Broadcast that we're no longer running
    if state.running do
      broadcast_status_change(false)
    end

    {:noreply, %{state | watcher_pid: nil, running: false}}
  end

  @impl true
  def terminate(_reason, state) do
    # Cancel timer if active
    if state.debounce_timer do
      Process.cancel_timer(state.debounce_timer)
    end

    # Process any remaining pending changes
    if MapSet.size(state.pending_changes) > 0 do
      handle_info(:process_changes, state)
    end

    # Note: FileSystem watcher will be stopped automatically by supervision tree
    :ok
  end

  # Private Functions

  @spec broadcast_status_change(boolean()) :: :ok | {:error, term()}
  defp broadcast_status_change(running) do
    Phoenix.PubSub.broadcast(
      CodeMySpec.PubSub,
      "file_watcher:status",
      {:file_watcher_status_changed, %{running: running}}
    )
  end
end
