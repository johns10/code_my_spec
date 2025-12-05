defmodule CodeMySpec.Environments.Cli do
  @moduledoc """
  Executes commands in tmux windows for CLI display.

  Commands run for demonstration purposes; output capture not supported.
  Delegates to TmuxAdapter for testability.
  """

  alias CodeMySpec.Environments.Cli.TmuxAdapter
  alias CodeMySpec.Environments.Environment

  @doc """
  Create a tmux window for command execution and return window reference.

  ## Options

  - `:session_id` - Used for window naming (e.g., "claude-123")

  ## Returns

  - `{:ok, window_ref}` - Window created successfully
  - `{:error, reason}` - Failed to create window (e.g., not inside tmux)
  """
  @spec create(opts :: keyword()) :: {:ok, String.t()} | {:error, term()}
  def create(opts \\ []) do
    unless TmuxAdapter.inside_tmux?() do
      {:error, "Not running inside tmux"}
    else
      session_id = Keyword.get(opts, :session_id, :rand.uniform(10000))
      window_name = "claude-#{session_id}"

      case TmuxAdapter.create_window(window_name) do
        {:ok, window_ref} ->
          {:ok, window_ref}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Destroy a tmux window and clean up resources.

  This function is idempotent - returns `:ok` even if the window doesn't exist.
  """
  @spec destroy(env :: Environment.t()) :: :ok | {:error, term()}
  def destroy(%Environment{ref: window_ref}) do
    case TmuxAdapter.kill_window(window_ref) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Send a command to the tmux window for display. Does not capture output.

  ## Options

  - `:env` - Map of environment variables to set before running command

  ## Returns

  - `:ok` - Command sent successfully
  - `{:error, reason}` - Failed to send command
  """
  @spec run_command(env :: Environment.t(), command :: String.t(), opts :: keyword()) ::
          :ok | {:error, term()}
  def run_command(%Environment{ref: window_ref}, command, opts \\ []) do
    env_vars = Keyword.get(opts, :env, %{})
    full_command = build_command_with_env(command, env_vars)

    TmuxAdapter.send_keys(window_ref, full_command)
  end

  @doc """
  Read a file from the server-side file system.

  The environment reference is not used since file operations are server-side.
  """
  @spec read_file(env :: Environment.t(), path :: String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def read_file(_env, path) do
    File.read(path)
  end

  @doc """
  List contents of a directory from the server-side file system.

  The environment reference is not used since file operations are server-side.
  """
  @spec list_directory(env :: Environment.t(), path :: String.t()) ::
          {:ok, [String.t()]} | {:error, term()}
  def list_directory(_env, path) do
    File.ls(path)
  end

  # Private functions

  defp build_command_with_env(command, env_vars) when map_size(env_vars) == 0 do
    command
  end

  defp build_command_with_env(command, env_vars) do
    exports =
      env_vars
      |> Enum.map(fn {key, value} -> "export #{key}=#{shell_escape(value)}" end)
      |> Enum.join("; ")

    "#{exports}; #{command}"
  end

  defp shell_escape(value) do
    # Simple shell escaping - wrap in single quotes and escape any single quotes
    "'#{String.replace(value, "'", "'\\''")}''"
  end
end
