defmodule CodeMySpec.Sessions.CurrentSession do
  @moduledoc """
  File-based persistence for tracking CLI session state between process invocations.

  Session state is stored in `.code_my_spec/internal/sessions/<session_id>/session.json`.
  The active session is identified by the `CODE_MY_SPEC_SESSION_ID` environment variable,
  which should be set by Claude Code when starting a session.

  This design supports multiple concurrent Claude instances, each with their own
  session identified by environment variable scope.
  """

  @sessions_dir ".code_my_spec/internal/sessions"
  @session_file "session.json"
  @env_var "CODE_MY_SPEC_SESSION_ID"

  @doc """
  Persists session state to disk as JSON.

  The session_id must be included in session_data and will be used to determine
  the storage directory.

  ## Fields stored:
  - session_id: Database session UUID
  - session_type: String name of the session type
  - component_id: Component ID
  - component_name: Component name for display
  - module_name: Component module name
  """
  @spec save(map()) :: :ok
  def save(session_data) when is_map(session_data) do
    session_id = Map.fetch!(session_data, :session_id)
    ensure_directory(session_id)
    json = Jason.encode!(session_data, pretty: true)
    File.write!(session_path(session_id), json)
    :ok
  end

  @doc """
  Loads session state from disk for the session identified by the environment variable.

  Returns {:ok, map} with atomized keys or {:error, reason}.
  Returns {:ok, nil} if no session ID is set in the environment.
  """
  @spec load() :: {:ok, map() | nil} | {:error, String.t()}
  def load do
    case get_session_id() do
      {:ok, nil} ->
        {:ok, nil}

      {:ok, session_id} ->
        load_session(session_id)
    end
  end

  @doc """
  Loads session state for a specific session ID.
  """
  @spec load_session(String.t()) :: {:ok, map() | nil} | {:error, String.t()}
  def load_session(session_id) do
    case File.read(session_path(session_id)) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, atomize_keys(data)}
          {:error, _} -> {:error, "Invalid session file format"}
        end

      {:error, :enoent} ->
        {:ok, nil}

      {:error, reason} ->
        {:error, "Failed to read session file: #{inspect(reason)}"}
    end
  end

  @doc """
  Gets the session ID from the environment variable.

  Returns {:ok, session_id} if set, {:ok, nil} if not set.
  """
  @spec get_session_id() :: {:ok, String.t() | nil}
  def get_session_id do
    {:ok, System.get_env(@env_var)}
  end

  @doc """
  Removes session state for the current session (identified by env var).
  """
  @spec clear() :: :ok
  def clear do
    case get_session_id() do
      {:ok, nil} -> :ok
      {:ok, session_id} -> clear_session(session_id)
    end
  end

  @doc """
  Removes session state for a specific session ID.
  """
  @spec clear_session(String.t()) :: :ok
  def clear_session(session_id) do
    session_dir = session_dir(session_id)

    if File.exists?(session_path(session_id)) do
      File.rm!(session_path(session_id))
    end

    # Clean up the session directory if empty
    if File.exists?(session_dir) and File.dir?(session_dir) do
      case File.ls(session_dir) do
        {:ok, []} -> File.rmdir(session_dir)
        _ -> :ok
      end
    end

    :ok
  end

  @doc """
  Checks if there's an active session (env var is set and file exists).
  """
  @spec active?() :: boolean()
  def active? do
    case get_session_id() do
      {:ok, nil} -> false
      {:ok, session_id} -> File.exists?(session_path(session_id))
    end
  end

  @doc """
  Returns the name of the environment variable used to identify the session.
  """
  @spec env_var_name() :: String.t()
  def env_var_name, do: @env_var

  # Private

  defp session_dir(session_id) do
    Path.join(@sessions_dir, session_id)
  end

  defp session_path(session_id) do
    Path.join([session_dir(session_id), @session_file])
  end

  defp ensure_directory(session_id) do
    File.mkdir_p!(session_dir(session_id))
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
