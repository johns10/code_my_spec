defmodule CodeMySpec.Environments.MockTmuxAdapter do
  @moduledoc """
  Mock implementation of TmuxAdapter for testing Cli environment in isolation.

  This mock allows testing Cli logic without requiring actual tmux.
  """

  @doc """
  Mock inside_tmux? - returns true by default.

  Can be configured via process dictionary for specific tests:
  ```
  Process.put(:mock_inside_tmux, false)
  ```
  """
  def inside_tmux? do
    Process.get(:mock_inside_tmux, true)
  end

  @doc """
  Mock get_current_session - returns a mock session name.
  """
  def get_current_session do
    {:ok, "mock-session"}
  end

  @doc """
  Mock create_window - returns a predictable window ID.
  """
  def create_window(window_name) do
    # Store window name in process dictionary to track created windows
    windows = Process.get(:mock_windows, MapSet.new())
    Process.put(:mock_windows, MapSet.put(windows, window_name))

    {:ok, "@mock-#{window_name}"}
  end

  @doc """
  Mock kill_window - always succeeds (idempotent).
  """
  def kill_window(window_name) do
    # Remove from tracked windows
    windows = Process.get(:mock_windows, MapSet.new())
    Process.put(:mock_windows, MapSet.delete(windows, window_name))

    :ok
  end

  @doc """
  Mock send_keys - records the command and returns success.
  """
  def send_keys(window_name, command) do
    # Store sent commands for verification if needed
    commands = Process.get(:mock_commands, [])
    Process.put(:mock_commands, [{window_name, command} | commands])

    :ok
  end

  @doc """
  Mock window_exists? - checks if window was created.
  """
  def window_exists?(window_name) do
    windows = Process.get(:mock_windows, MapSet.new())
    MapSet.member?(windows, window_name)
  end

  @doc """
  Reset mock state - useful in test setup.
  """
  def reset! do
    Process.delete(:mock_inside_tmux)
    Process.delete(:mock_windows)
    Process.delete(:mock_commands)
  end

  @doc """
  Get commands sent via send_keys for verification.
  """
  def get_sent_commands do
    Process.get(:mock_commands, [])
    |> Enum.reverse()
  end
end
