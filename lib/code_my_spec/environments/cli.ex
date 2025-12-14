defmodule CodeMySpec.Environments.Cli do
  @moduledoc """
  Executes commands in tmux windows for CLI display.

  Commands run for demonstration purposes; output capture not supported.
  Delegates to TmuxAdapter for testability.
  """

  alias CodeMySpec.Environments.Cli.TmuxAdapter
  alias CodeMySpec.Environments.Environment
  require Logger

  # Allow adapter injection for testing
  defp adapter do
    Application.get_env(:code_my_spec, :tmux_adapter, TmuxAdapter)
  end

  @doc """
  Create an environment for command execution (lazy window creation).

  The tmux window is not created immediately. Instead, it's created on-demand
  when the first command runs. This allows for more efficient resource usage.

  ## Options

  - `:session_id` - Used for window naming (e.g., "session-123")
  - `:metadata` - Optional metadata to include in Environment struct

  ## Returns

  - `{:ok, %Environment{}}` - Environment created successfully
  - `{:error, reason}` - Failed to validate environment (e.g., not inside tmux)
  """
  @spec create(opts :: keyword()) :: {:ok, Environment.t()} | {:error, term()}
  def create(opts \\ []) do
    unless adapter().inside_tmux?() do
      {:error, "Not running inside tmux"}
    else
      session_id = Keyword.get(opts, :session_id, :rand.uniform(10000))
      window_name = "session-#{session_id}"
      metadata = Keyword.get(opts, :metadata, %{})

      {:ok,
       %Environment{
         type: :cli,
         ref: window_name,
         metadata: metadata
       }}
    end
  end

  @doc """
  Destroy a tmux window and clean up resources.

  This function is idempotent - returns `:ok` even if the window doesn't exist.
  Since window creation is lazy, this might be called on a window that was never created.
  """
  @spec destroy(env :: Environment.t()) :: :ok | {:error, term()}
  def destroy(%Environment{ref: window_name}) do
    case adapter().kill_window(window_name) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Send a command to the tmux window for display. Does not capture output.

  Pattern matches on command type and dispatches appropriately.

  ## Returns

  - `:ok` - Command sent successfully
  - `{:error, reason}` - Failed to send command
  """
  @spec run_command(
          env :: Environment.t(),
          command :: CodeMySpec.Sessions.Command.t(),
          opts :: keyword()
        ) ::
          :ok | {:ok, map()} | {:error, term()}
  def run_command(_env, _command, _opts \\ [])

  # Handle empty commands - auto-complete with success
  def run_command(
        %Environment{},
        %CodeMySpec.Sessions.Command{command: cmd},
        _opts
      )
      when cmd == "" or is_nil(cmd) do
    {:ok, %{}}
  end

  def run_command(
        %Environment{} = env,
        %CodeMySpec.Sessions.Command{command: "read_file", metadata: %{path: path}},
        _opts
      ) do
    read_file(env, path)
  end

  def run_command(
        %Environment{} = env,
        %CodeMySpec.Sessions.Command{command: "list_directory", metadata: %{path: path}},
        _opts
      ) do
    list_directory(env, path)
  end

  def run_command(
        %Environment{ref: window_name},
        %CodeMySpec.Sessions.Command{command: "claude" = cmd},
        opts
      ) do
    with :ok <- ensure_window_exists(window_name) do
      env_vars = Keyword.get(opts, :env, %{})
      full_command = build_command_with_env(cmd, env_vars)

      adapter().send_keys(window_name, full_command)
    end
  end

  # Fallback for legacy format where command field contains the actual shell command
  def run_command(
        %Environment{ref: window_name},
        %CodeMySpec.Sessions.Command{command: cmd},
        opts
      )
      when is_binary(cmd) do
    with :ok <- ensure_window_exists(window_name) do
      env_vars = Keyword.get(opts, :env, %{})
      full_command = build_command_with_env(cmd, env_vars)

      adapter().send_keys(window_name, full_command)
    end
  end

  def environment_setup_command(_), do: ""

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

  @doc false
  defp ensure_window_exists(window_name) do
    unless adapter().window_exists?(window_name) do
      case adapter().create_window(window_name) do
        {:ok, _window_id} ->
          Logger.debug("Created tmux window: #{window_name}")
          :ok

        {:error, reason} ->
          Logger.error("Failed to create tmux window #{window_name}: #{inspect(reason)}")
          {:error, reason}
      end
    else
      :ok
    end
  end

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
