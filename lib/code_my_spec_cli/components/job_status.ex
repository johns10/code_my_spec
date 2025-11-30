defmodule CodeMySpecCli.Components.JobStatus do
  @moduledoc """
  A status indicator component that displays running background jobs.
  Subscribes to PubSub events and only shows when jobs are active.
  """

  use GenServer
  require Logger

  @type state :: %{
          file_watcher_running: boolean(),
          subscribers: [pid()]
        }

  # Client API

  @doc """
  Starts the JobStatus component server.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Subscribes the calling process to job status updates.
  When status changes, the subscriber will receive:
  {:job_status_changed, %{file_watcher_running: boolean()}}
  """
  @spec subscribe() :: :ok
  def subscribe do
    GenServer.call(__MODULE__, :subscribe)
  end

  @doc """
  Gets the current job status.
  """
  @spec get_status() :: %{file_watcher_running: boolean()}
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Renders the job status indicator.
  Returns empty string if nothing is running, otherwise returns a status line.
  """
  @spec render() :: iodata()
  def render do
    status = get_status()

    if status.file_watcher_running do
      # Show a pulsing indicator when file watcher is running
      indicator = Owl.Data.tag("[*]", :green)
      text = Owl.Data.tag(" Files syncing...", :light_black)
      [indicator, text]
    else
      ""
    end
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Subscribe to file watcher status changes
    Phoenix.PubSub.subscribe(CodeMySpec.PubSub, "file_watcher:status")

    # Start with false - we'll get the actual status via PubSub events
    # This avoids blocking on FileWatcherServer during startup
    Logger.info("JobStatus component started, waiting for file watcher status events")

    {:ok,
     %{
       file_watcher_running: false,
       subscribers: []
     }}
  end

  @impl true
  def handle_call(:subscribe, {pid, _}, state) do
    # Add subscriber and monitor them
    Process.monitor(pid)
    new_subscribers = [pid | state.subscribers] |> Enum.uniq()

    {:reply, :ok, %{state | subscribers: new_subscribers}}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{file_watcher_running: state.file_watcher_running}
    {:reply, status, state}
  end

  @impl true
  def handle_info({:file_watcher_status_changed, %{running: running}}, state) do
    Logger.debug("JobStatus received file_watcher status change: #{running}")

    # Notify all subscribers
    Enum.each(state.subscribers, fn pid ->
      send(pid, {:job_status_changed, %{file_watcher_running: running}})
    end)

    {:noreply, %{state | file_watcher_running: running}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove dead subscriber
    new_subscribers = Enum.reject(state.subscribers, &(&1 == pid))
    {:noreply, %{state | subscribers: new_subscribers}}
  end
end
