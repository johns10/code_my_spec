defmodule CodeMySpec.Sessions.CurrentSession do
  @moduledoc """
  File-based persistence for tracking the active CLI session between process invocations.

  Stores session state in `.code_my_spec/internal/current_session/session.json`
  so the evaluate command can pick up context from the start command without
  bash script intermediaries.
  """

  @session_dir ".code_my_spec/internal/current_session"
  @session_file "session.json"

  @doc """
  Persists current session state to disk as JSON.

  ## Fields stored:
  - session_id: Database session ID
  - session_type: String name of the session type
  - component_id: Component ID
  - component_name: Component name for display
  - module_name: Component module name
  """
  @spec save(map()) :: :ok
  def save(session_data) when is_map(session_data) do
    ensure_directory()
    json = Jason.encode!(session_data, pretty: true)
    File.write!(session_path(), json)
    :ok
  end

  @doc """
  Loads current session state from disk.

  Returns {:ok, map} with atomized keys or {:error, reason}
  """
  @spec load() :: {:ok, map()} | {:error, String.t()}
  def load do
    case File.read(session_path()) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, atomize_keys(data)}
          {:error, _} -> {:error, "Invalid session file format"}
        end

      {:error, :enoent} ->
        {:error, "No active session. Run a start command first."}

      {:error, reason} ->
        {:error, "Failed to read session file: #{inspect(reason)}"}
    end
  end

  @doc """
  Convenience function to get just the session ID from disk.
  """
  @spec get_session_id() :: {:ok, integer()} | {:error, String.t()}
  def get_session_id do
    case load() do
      {:ok, %{session_id: id}} -> {:ok, id}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Removes current session state after successful completion.
  """
  @spec clear() :: :ok
  def clear do
    if File.exists?(session_path()) do
      File.rm!(session_path())
    end

    # Also clean up the directory if empty
    if File.exists?(@session_dir) and File.dir?(@session_dir) do
      case File.ls(@session_dir) do
        {:ok, []} -> File.rmdir(@session_dir)
        _ -> :ok
      end
    end

    :ok
  end

  @doc """
  Checks if there's an active session on disk.
  """
  @spec active?() :: boolean()
  def active? do
    File.exists?(session_path())
  end

  # Private

  defp session_path do
    Path.join(@session_dir, @session_file)
  end

  defp ensure_directory do
    File.mkdir_p!(@session_dir)
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
