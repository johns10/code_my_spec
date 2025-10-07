defmodule CodeMySpec.ContentSync.FileWatcher do
  @moduledoc """
  GenServer that monitors local content directories for file changes during development.

  Watches configured filesystem paths using the FileSystem library and triggers content
  sync operations when files are modified. Started conditionally based on environment
  configuration (development only).

  ## Configuration

      # config/dev.exs
      config :code_my_spec,
        watch_content: true,
        content_watch_directory: "/Users/developer/my_project/content",
        content_watch_scope: %{
          account_id: "dev_account",
          project_id: "dev_project"
        }

      # config/prod.exs
      config :code_my_spec,
        watch_content: false

  ## Supervision Tree

  Add to application.ex:

      children =
        if Application.get_env(:code_my_spec, :watch_content, false) do
          [ContentSync.FileWatcher | children]
        else
          children
        end

  """

  use GenServer
  require Logger

  alias CodeMySpec.ContentSync.Sync
  alias CodeMySpec.Users.Scope

  defstruct [:scope, :watched_directory, :debounce_timer]

  @debounce_ms 1000

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Starts the FileWatcher GenServer.

  Returns `:ignore` if `:watch_content` config is disabled, otherwise starts
  the GenServer and subscribes to FileSystem events for the configured directory.

  ## Options

  Accepts an options keyword list (currently unused, but required for child_spec).

  ## Returns

    - `{:ok, pid}` - Successfully started GenServer
    - `:ignore` - File watching is disabled in configuration
    - `{:error, reason}` - Failed to start due to invalid configuration

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    case Application.get_env(:code_my_spec, :watch_content) do
      true ->
        GenServer.start_link(__MODULE__, opts)

      _ ->
        :ignore
    end
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    case load_and_validate() do
      {:ok, directory, scope} ->
        case subscribe_to_filesystem(directory) do
          {:ok, _pid} ->
            state = %__MODULE__{
              scope: scope,
              watched_directory: directory,
              debounce_timer: nil
            }

            Logger.info(
              "FileWatcher started: watching #{directory} for account_id=#{scope.active_account_id} project_id=#{scope.active_project_id}"
            )

            {:ok, state}

          {:error, reason} ->
            {:stop, reason}
        end

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @spec load_and_validate() :: {:ok, String.t(), Scope.t()} | {:error, term()}
  defp load_and_validate do
    with {:ok, directory} <- load_directory(),
         {:ok, scope} <- load_scope(),
         :ok <- validate_directory(directory) do
      {:ok, directory, scope}
    end
  end

  @impl true
  def handle_info({:file_event, _watcher_pid, {_path, events}}, state) do
    if relevant_event?(events) do
      if state.debounce_timer do
        Process.cancel_timer(state.debounce_timer)
      end

      timer_ref = Process.send_after(self(), :trigger_sync, @debounce_ms)

      {:noreply, %{state | debounce_timer: timer_ref}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:trigger_sync, state) do
    case Sync.sync_directory(state.scope, state.watched_directory) do
      {:ok, result} ->
        Logger.info("FileWatcher: Content synced successfully", result: result)

      {:error, reason} ->
        Logger.error("FileWatcher: Sync failed", reason: reason)
    end

    {:noreply, %{state | debounce_timer: nil}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.debounce_timer do
      Process.cancel_timer(state.debounce_timer)
    end

    :ok
  end

  # ============================================================================
  # Configuration Loading
  # ============================================================================

  @spec load_directory() :: {:ok, String.t()} | {:error, :missing_directory_config}
  defp load_directory do
    case Application.get_env(:code_my_spec, :content_watch_directory) do
      nil ->
        {:error, :missing_directory_config}

      "" ->
        {:error, :missing_directory_config}

      directory when is_binary(directory) ->
        {:ok, directory}
    end
  end

  @spec load_scope() :: {:ok, Scope.t()} | {:error, :missing_scope_config}
  defp load_scope do
    case Application.get_env(:code_my_spec, :content_watch_scope) do
      nil ->
        {:error, :missing_scope_config}

      %{account_id: account_id, project_id: project_id}
      when not is_nil(account_id) and not is_nil(project_id) ->
        scope = %Scope{
          active_account_id: account_id,
          active_project_id: project_id
        }

        {:ok, scope}

      _ ->
        {:error, :missing_scope_config}
    end
  end

  # ============================================================================
  # Directory Validation
  # ============================================================================

  @spec validate_directory(String.t()) :: :ok | {:error, :invalid_directory}
  defp validate_directory(directory) do
    cond do
      not File.exists?(directory) ->
        {:error, :invalid_directory}

      not File.dir?(directory) ->
        {:error, :invalid_directory}

      true ->
        :ok
    end
  end

  # ============================================================================
  # FileSystem Integration
  # ============================================================================

  @spec subscribe_to_filesystem(String.t()) :: {:ok, pid()} | {:error, term()}
  defp subscribe_to_filesystem(directory) do
    case FileSystem.start_link(dirs: [directory]) do
      {:ok, pid} ->
        FileSystem.subscribe(pid)
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # Event Filtering
  # ============================================================================

  @spec relevant_event?(list()) :: boolean()
  defp relevant_event?(events) when is_list(events) do
    Enum.any?(events, fn event ->
      event in [:modified, :created, :removed]
    end)
  end

  defp relevant_event?(_), do: false
end
