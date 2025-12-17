defmodule CodeMySpecCli.TmuxManager do
  @moduledoc """
  Manages tmux session orchestration for CodeMySpec CLI.

  This module provides programmatic control over tmux windows and panes,
  allowing the Ratatouille TUI to spawn and manage Claude Code sessions
  in separate tmux windows.

  ## Architecture

  - Ratatouille runs in Window 0 (the control panel)
  - Each Claude Code session runs in its own tmux window
  - Users can switch between windows using Ctrl+B shortcuts or the TUI
  - All communication happens via tmux CLI commands
  """

  require Logger

  @parent_session_name "codemyspec-main"

  @doc """
  Returns the parent tmux session name used by CodeMySpec.
  """
  def parent_session_name, do: @parent_session_name

  @doc """
  Initialize tmux orchestration at startup.

  Detects if running inside tmux and whether tmux is available.
  Returns a map with tmux availability status and parent session info.
  """
  def init do
    cond do
      inside_tmux?() ->
        session = get_current_session()
        Logger.info("Running inside tmux session: #{session}")
        {:ok, %{tmux_available: true, parent_session: session}}

      tmux_available?() ->
        Logger.info("Tmux available but not running inside tmux")
        {:ok, %{tmux_available: true, parent_session: nil}}

      true ->
        Logger.warning("Tmux not available; sessions will run in background processes")
        {:ok, %{tmux_available: false, parent_session: nil}}
    end
  end

  @doc """
  Check if currently running inside a tmux session.
  """
  def inside_tmux? do
    case System.get_env("TMUX") do
      nil -> false
      "" -> false
      _value -> true
    end
  end

  @doc """
  Check if tmux is installed and available.
  """
  def tmux_available? do
    case System.cmd("which", ["tmux"], stderr_to_stdout: true) do
      {_path, 0} -> true
      _ -> false
    end
  rescue
    _error -> false
  end

  @doc """
  Get the name of the current tmux session.
  """
  def get_current_session do
    case System.cmd("tmux", ["display-message", "-p", "\#{session_name}"]) do
      {session, 0} -> String.trim(session)
      {_error, _code} -> nil
    end
  end

  @doc """
  Create a new tmux pane (split) in Window 0 for a Claude Code session.

  ## Parameters

    - `session_id` - The database session ID
    - `component_id` - The component this session is for

  ## Returns

    - `{:ok, pane_id}` on success
    - `{:error, reason}` on failure
  """
  def create_session_pane(session_id, _component_id) do
    if tmux_available?() do
      parent_session = get_current_session() || @parent_session_name
      pane_title = "session-#{session_id}"

      # Create a split pane in Window 0
      case System.cmd("tmux", [
        "split-window",
        "-v",  # Horizontal split (top/bottom)
        "-l", "50%",  # 50% height
        "-t", "#{parent_session}:0",
        "-P", "-F", "\#{pane_id}",  # Print the pane ID
        "-d"  # Don't switch to it
      ]) do
        {pane_id, 0} ->
          pane_id = String.trim(pane_id)

          # Set the pane title so we can find it later
          System.cmd("tmux", [
            "select-pane",
            "-t", pane_id,
            "-T", pane_title
          ])

          # Enter copy mode by default so the pane is scrollable
          System.cmd("tmux", ["copy-mode", "-t", pane_id])

          Logger.info("Created session pane: #{pane_title} (#{pane_id}) in copy mode")
          {:ok, pane_id}

        {error, _code} ->
          Logger.error("Failed to create session pane: #{error}")
          {:error, error}
      end
    else
      {:error, "Tmux not available"}
    end
  end

  @doc """
  Find a pane by its title.

  ## Returns

    - `{:ok, pane_id}` if found
    - `{:error, :not_found}` if not found
  """
  def find_pane_by_title(title) do
    session = get_current_session() || @parent_session_name

    case System.cmd("tmux", [
      "list-panes",
      "-t", "#{session}:0",
      "-F", "\#{pane_id}:\#{pane_title}"
    ]) do
      {output, 0} ->
        panes = output
        |> String.trim()
        |> String.split("\n")
        |> Enum.map(fn line ->
          case String.split(line, ":", parts: 2) do
            [pane_id, pane_title] -> {pane_id, pane_title}
            _ -> {nil, nil}
          end
        end)

        case Enum.find(panes, fn {_id, pane_title} -> pane_title == title end) do
          {pane_id, _} -> {:ok, pane_id}
          nil -> {:error, :not_found}
        end

      {_error, _code} ->
        {:error, :not_found}
    end
  end

  @doc """
  Focus a pane by its title.
  """
  def focus_pane_by_title(title) do
    case find_pane_by_title(title) do
      {:ok, pane_id} ->
        System.cmd("tmux", ["select-pane", "-t", pane_id])
        :ok

      error ->
        error
    end
  end

  @doc """
  Send keys to a pane by its title.

  This will exit copy mode, send the command, then re-enter copy mode
  after a brief delay to allow the command to start executing.
  """
  def send_keys_to_pane(title, text) do
    case find_pane_by_title(title) do
      {:ok, pane_id} ->
        # Exit copy mode first (if in it)
        System.cmd("tmux", ["send-keys", "-t", pane_id, "-X", "cancel"])

        # Send the command
        result = System.cmd("tmux", [
          "send-keys",
          "-t", pane_id,
          text,
          "C-m"
        ])

        # Wait a moment for the command to start
        Process.sleep(100)

        # Re-enter copy mode so the pane stays scrollable
        System.cmd("tmux", ["copy-mode", "-t", pane_id])

        case result do
          {_output, 0} -> :ok
          {error, _code} -> {:error, error}
        end

      error ->
        error
    end
  end

  @doc """
  Enter copy mode (scroll mode) in the bottom pane.

  This allows you to scroll through the output using arrow keys.
  Press 'q' to exit copy mode.
  """
  def enter_copy_mode_bottom_pane do
    session = get_current_session() || @parent_session_name

    # List panes and find the one that's not pane 0 (the bottom one)
    case System.cmd("tmux", [
      "list-panes",
      "-t", "#{session}:0",
      "-F", "\#{pane_id}:\#{pane_index}"
    ]) do
      {output, 0} ->
        panes = output
        |> String.trim()
        |> String.split("\n")
        |> Enum.map(fn line ->
          case String.split(line, ":", parts: 2) do
            [pane_id, index] -> {pane_id, index}
            _ -> {nil, "0"}
          end
        end)

        # Find the last pane (highest index)
        case Enum.max_by(panes, fn {_id, index} -> String.to_integer(index) end, fn -> nil end) do
          {pane_id, _} when not is_nil(pane_id) ->
            # Enter copy mode in that pane
            case System.cmd("tmux", ["copy-mode", "-t", pane_id]) do
              {_output, 0} ->
                Logger.info("Entered copy mode in pane #{pane_id}")
                :ok
              {error, _code} -> {:error, error}
            end

          _ ->
            {:error, "No bottom pane found"}
        end

      {error, _code} ->
        {:error, error}
    end
  end

  @doc """
  Create a new tmux window for a Claude Code session.

  ## Parameters

    - `session_id` - The database session ID
    - `component_id` - The component this session is for
    - `command` - Optional command to run (defaults to interactive shell)

  ## Returns

    - `{:ok, window_name}` on success
    - `{:error, reason}` on failure
  """
  def create_session_window(session_id, component_id, command \\ nil) do
    if tmux_available?() do
      parent_session = get_current_session() || @parent_session_name
      window_name = "claude-#{session_id}"

      # Build the command to run in the window
      window_command = command || build_default_session_command(session_id, component_id)

      case spawn_window(parent_session, window_name, window_command) do
        :ok ->
          Logger.info("Created Claude Code window: #{window_name}")
          {:ok, window_name}

        {:error, reason} ->
          Logger.error("Failed to create tmux window: #{reason}")
          {:error, reason}
      end
    else
      {:error, "Tmux not available"}
    end
  end

  @doc """
  List all windows in the current tmux session.

  Returns a list of maps with window information:
  - `name` - Window name
  - `id` - Window ID
  - `active` - Boolean indicating if this is the active window
  """
  def list_windows(session_name \\ nil) do
    session = session_name || get_current_session() || @parent_session_name

    case System.cmd("tmux", [
      "list-windows",
      "-t", session,
      "-F", "\#{window_name}|\#{window_id}|\#{window_active}"
    ]) do
      {output, 0} ->
        windows =
          output
          |> String.trim()
          |> String.split("\n")
          |> Enum.map(&parse_window_line/1)

        {:ok, windows}

      {"", _code} ->
        {:ok, []}

      {error, _code} ->
        Logger.error("Failed to list windows: #{error}")
        {:error, error}
    end
  end

  @doc """
  Switch focus to a specific window.

  This makes the specified window visible in the terminal.
  """
  def focus_window(window_name, session_name \\ nil) do
    session = session_name || get_current_session() || @parent_session_name

    case System.cmd("tmux", [
      "select-window",
      "-t", "#{session}:#{window_name}"
    ]) do
      {_output, 0} ->
        Logger.debug("Focused window: #{window_name}")
        :ok

      {error, _code} ->
        Logger.error("Failed to focus window #{window_name}: #{error}")
        {:error, error}
    end
  end

  @doc """
  Create a split pane showing another tmux window.

  This splits the current pane horizontally (top/bottom) and shows the target
  window in the bottom pane. The Ratatouille dashboard stays in the top pane.

  ## Parameters
    - `target_window` - The window to display in the bottom split pane
    - `direction` - `:horizontal` (top/bottom, default) or `:vertical` (left/right)
    - `size` - Optional percentage size (e.g., "50%")
  """
  def split_and_show_window(target_window, direction \\ :horizontal, size \\ nil) do
    session = get_current_session() || @parent_session_name

    # Build the split command using join-pane
    # -v = horizontal split (top/bottom)
    # -h = vertical split (left/right)
    split_flag = if direction == :horizontal, do: "-v", else: "-h"
    size_flag = if size, do: ["-l", size], else: []

    # Use join-pane to bring the target window's pane into Window 0 as a split
    # -d keeps focus on the current pane (top)
    # Note: This will temporarily destroy the target window, but close_splits will restore it
    args =
      ["join-pane", split_flag, "-d"] ++
        size_flag ++
        ["-s", "#{session}:#{target_window}.0", "-t", "#{session}:0"]

    case System.cmd("tmux", args) do
      {_output, 0} ->
        Logger.info("Created split pane showing window: #{target_window}")
        :ok

      {error, _code} ->
        Logger.error("Failed to create split pane: #{error}")
        {:error, error}
    end
  end

  @doc """
  Kill all panes except the main one in the current window.

  Useful for closing split views and returning to full screen.
  For panes that were joined from other windows, breaks them back out.
  """
  def close_splits(window_name \\ nil) do
    session = get_current_session() || @parent_session_name
    target = if window_name, do: "#{session}:#{window_name}", else: "#{session}:0"

    # Get the main pane ID (pane 0)
    case System.cmd("tmux", [
      "display-message",
      "-t", "#{target}.0",
      "-p", "\#{pane_id}"
    ]) do
      {main_pane_id, 0} ->
        main_pane_id = String.trim(main_pane_id)

        # List all panes in the window
        case System.cmd("tmux", [
          "list-panes",
          "-t", target,
          "-F", "\#{pane_id}:\#{window_name}"
        ]) do
          {output, 0} ->
            output
            |> String.trim()
            |> String.split("\n")
            |> Enum.each(fn line ->
              case String.split(line, ":", parts: 2) do
                [pane_id, original_window] when pane_id != main_pane_id ->
                  # Break pane back to its original window name if it starts with "claude-"
                  if String.starts_with?(original_window, "claude-") do
                    System.cmd("tmux", [
                      "break-pane",
                      "-d",
                      "-s", pane_id,
                      "-n", original_window
                    ])
                  else
                    # Just kill it if it's not a session pane
                    System.cmd("tmux", ["kill-pane", "-t", pane_id])
                  end

                _ ->
                  :ok
              end
            end)

            :ok

          {error, _} ->
            {:error, error}
        end

      {error, _} ->
        {:error, error}
    end
  end

  @doc """
  Send a command/text to a specific window.

  The command will be typed into the window as if the user typed it,
  followed by Enter (C-m).
  """
  def send_keys(window_name, text, session_name \\ nil) do
    session = session_name || get_current_session() || @parent_session_name

    case System.cmd("tmux", [
      "send-keys",
      "-t", "#{session}:#{window_name}",
      text,
      "C-m"
    ]) do
      {_output, 0} -> :ok
      {error, _code} -> {:error, error}
    end
  end

  @doc """
  Kill/close a specific window.
  """
  def kill_window(window_name, session_name \\ nil) do
    session = session_name || get_current_session() || @parent_session_name

    case System.cmd("tmux", [
      "kill-window",
      "-t", "#{session}:#{window_name}"
    ]) do
      {_output, 0} ->
        Logger.info("Killed window: #{window_name}")
        :ok

      {error, _code} ->
        Logger.warning("Failed to kill window #{window_name}: #{error}")
        {:error, error}
    end
  end

  @doc """
  Capture the visible content of a window's pane.

  Useful for monitoring output or checking session state.
  """
  def capture_pane(window_name, session_name \\ nil) do
    session = session_name || get_current_session() || @parent_session_name

    case System.cmd("tmux", [
      "capture-pane",
      "-t", "#{session}:#{window_name}",
      "-p"
    ]) do
      {content, 0} -> {:ok, content}
      {error, _code} -> {:error, error}
    end
  end

  @doc """
  Get the process ID of the main process running in a window.
  """
  def get_pane_pid(window_name, session_name \\ nil) do
    session = session_name || get_current_session() || @parent_session_name

    case System.cmd("tmux", [
      "display-message",
      "-t", "#{session}:#{window_name}",
      "-p", "\#{pane_pid}"
    ]) do
      {pid_str, 0} ->
        pid_str
        |> String.trim()
        |> String.to_integer()
        |> then(&{:ok, &1})

      {error, _code} -> {:error, error}
    end
  end

  @doc """
  Check if a window exists.
  """
  def window_exists?(window_name, session_name \\ nil) do
    case list_windows(session_name) do
      {:ok, windows} ->
        Enum.any?(windows, &(&1.name == window_name))

      {:error, _} ->
        false
    end
  end

  # Private functions

  defp spawn_window(session, window_name, command) do
    case System.cmd("tmux", [
      "new-window",
      "-t", session,
      "-n", window_name,
      "-d",  # Don't switch to it immediately
      "bash", "-c", command
    ]) do
      {_output, 0} -> :ok
      {error, _code} -> {:error, error}
    end
  end

  defp parse_window_line(line) do
    case String.split(line, "|") do
      [name, id, active] ->
        %{
          name: name,
          id: id,
          active: active == "1"
        }

      _ ->
        %{name: "unknown", id: "", active: false}
    end
  end

  defp build_default_session_command(session_id, component_id) do
    """
    set -e
    echo "Starting Claude Code session #{session_id} for component #{component_id}"
    echo "Press Ctrl+C to stop, or Ctrl+B 0 to return to the dashboard"
    echo ""

    # Keep the shell alive - in the future, this will launch claude-code CLI
    # For now, just an interactive bash shell
    exec bash
    """
  end
end
